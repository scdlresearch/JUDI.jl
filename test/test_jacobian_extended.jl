# Example for basic 2D modeling:
# The receiver positions and the source wavelets are the same for each of the four experiments.
# Author: Philipp Witte, pwitte@eos.ubc.ca
# Date: January 2017
#

using JUDI.TimeModeling, SegyIO, LinearAlgebra, Images, Test

## Set up model structure
n = (120, 100)   # (x,y,z) or (x,z)
d = (10., 10.)
o = (0., 0.)

# Velocity [km/s]
v = ones(Float32,n) .+ 0.4f0
v[:,Int(round(end/2)):end] .= 3.5f0
v0 = imfilter(v, Float32.(Kernel.gaussian(10)))

# Slowness squared [s^2/km^2]
m = (1f0 ./ v).^2
m0 = (1f0 ./ v0).^2
dm = vec(m - m0)

# Setup info and model structure
nsrc = 1	# number of sources
model = Model(n, d, o, m)
model0 = Model(n, d, o, m0)

## Set up receiver geometry
nxrec = 120
xrec = range(50f0, stop=1150f0, length=nxrec)
yrec = 0f0
zrec = range(50f0, stop=50f0, length=nxrec)

# receiver sampling and recording time
time = 500f0   # receiver recording time [ms]
dt = 1f0    # receiver sampling interval [ms]

# Set up receiver structure
recGeometry = Geometry(xrec, yrec, zrec; dt=dt, t=time, nsrc=nsrc)

# setup wavelet
f0 = 0.01f0     # MHz
wavelet = ricker_wavelet(time, dt, f0)

# Set up info structure for linear operators
ntComp = get_computational_nt(recGeometry, model)
info = Info(prod(n), nsrc, ntComp)

###################################################################################

# Write shots as segy files to disk
opt = Options(sum_padding=true, dt_comp=dt, return_array=true)

# Setup operators
Pr = judiProjection(info, recGeometry)
F = judiModeling(info, model; options=opt)
F0 = judiModeling(info, model0; options=opt)
Pw = judiLRWF(info, wavelet)

# Combined operators
A = Pr*F*adjoint(Pw)
A0 = Pr*F0*adjoint(Pw)

# Extended source weights
w = judiWeights(randn(Float32, model0.n))
J = judiJacobian(Pr*F0*Pw', w)

# Nonlinear modeling
dpred = A0*w
dD = J*dm

# Jacobian test
maxiter = 6
h = .1f0
err1 = zeros(Float32, maxiter)
err2 = zeros(Float32, maxiter)

for j=1:maxiter

    A.model.m = m0 + h*reshape(dm, model0.n)
    dobs = A*w

    err1[j] = norm(dobs - dpred)
    err2[j] = norm(dobs - dpred - h*dD)
    print(h, " ", err1[j], "    ", err2[j],"\n")

    global h = h/2f0
end

@test isapprox(err1[end] / (err1[1]/2^(maxiter-1)), 1f0; atol=1f1)
@test isapprox(err2[end] / (err2[1]/4^(maxiter-1)), 1f0; atol=1f1)