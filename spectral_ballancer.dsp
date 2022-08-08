declare name      "spectral_balancer";
declare author    "Klaus Scheuermann";
declare version   "0.1";
declare copyright "(C) 2022 Klaus Scheuermann";



import("stdfaust.lib");

O = 5;
M = 2;
ftop = 12000;
B = 8;
BANDS = 4;
process(l,r) = hgroup("spectral balancer",
l,r <: _,_,_,_   :  _,_,+  :  _,_, envelop  :  _,_,vbargraph("[0]full",-60,0)  :  fibank_st,(_<:par(i,B*2,_))  :  route1  :  par(i,B,bandgain(i))  :>  _,_  )
;

route1 = ro.interleave(B*2,2)  :  par(i,B,route(4,4,1,1,2,3,3,2,4,4) : _,_,_,!)   ;

// hgroup("spectral balancer", hgroup("[2]filterbank",  fibank_st : par(i,BANDS, bandgain(l,r,i)) : par(i,BANDS, stereogain(i)) :> _,_));

fibank_mono = fi.mth_octave_filterbank(O,M,ftop,B) : ro.cross(B);
fibank_st = par(i,2,fibank_mono :  par(i,B,_) ) : ro.interleave(B,2);

// bandgain(l,r,i) = l,r,_,_ : _,_,(_<:_,_),(_<:_,_)  :   _,_,(route(4,4,1,1,2,3,3,2,4,4))   :   (_,_ :> envelop : vbargraph("full %i",-60,0)),(_,_ :> envelop : vbargraph("band %i",-60,0)),_,_   : calcamp(i),_,_ : multiply3;
bandgain(i) = (_<:_,_),(_<:_,_),_  :  (route(4,4,1,1,2,3,3,2,4,4)),_   :  _,_,+,_  :  _,_,envelop,_  :  _,_,vbargraph("band %2i",-60,0),_  :  _,_,calcamp(i)  :  multiply3;

//calcamp(i,a,b) = a-b + i -10: si.smoo : ba.db2linear : vbargraph("calc %i",1,10);
calcamp(i) = _,_  :  ro.cross(2)  :  ba.db2linear,ba.db2linear  :  -  :  vbargraph("calc %2i",0,1)   ;


multiply3(x,y,g) = x*g,y*g;



stereogain(i) = (_  * (vslider("gain %2i",0,-12,+12,0.5) :ba.db2linear)) , (_  * (vslider("gain %2i",0,-12,+12,0.5) :ba.db2linear));


// envelop = abs : max(ba.db2linear(-70)) : ba.linear2db : min(10)  : max ~ -(20.0/ma.SR);
envelop = Lk;








// LUFS metering (without channel weighting)
Tg = 3; // 3 second window for 'short-term' measurement
// zi = an.ms_envelope_rect(Tg); // mean square: average power = energy/Tg = integral of squared signal / Tg

//k-filter by Julius Smith
highpass = fi.highpass(2, 40);
boostDB = 4;
boostFreqHz = 1430; // a little too high - they should give us this!
highshelf = fi.high_shelf(boostDB, boostFreqHz); // Looks very close, but 1 kHz gain has to be nailed
kfilter = highshelf : highpass;

//envelope via lp by Dario Sanphilippo
lp1p(cf, x) = fi.pole(b, x * (1 - b)) with {
    b = exp(-2 * ma.PI * cf / ma.SR);
};
zi_lp(x) = lp1p(1 / Tg, x * x);

// one channel
Lk = kfilter: zi_lp : 10 * log10(max(ma.EPSILON)) : -(0.691);

// N-channel
LkN = par(i,Nch,kfilter : zi_lp) :> 10 * log10(max(ma.EPSILON)) : -(0.691);

// N-channel by Yann Orlarey
lufs_any(N) = B <: B, (B :> Lk : vbargraph("LUFS S",-60,0)) : si.bus(N-1), attach(_,_)
    with { 
        B = si.bus(N); 
        
    };

LUFS_in_meter(x,y) = x,y <: x, attach(y, (LkN : hgroup("MASTER_ME", hgroup("[0]INPUT",vbargraph("LUFS S",-60,0))))) : _,_;
LUFS_out_meter(x,y) = x,y <: x, attach(y, (LkN : hgroup("MASTER_ME", hgroup("[9]OUTPUT",vbargraph("LUFS S",-60,0))))) : _,_;




