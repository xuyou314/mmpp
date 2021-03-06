library(expm)

repmat = function(X,m,n){
  ##R equivalent of repmat (matlab)
  mx = dim(X)[1]
  nx = dim(X)[2]
  matrix(t(matrix(X,mx,nx*n)),mx*m,nx*n,byrow=T)
}

priors<-list()
priors$aL=1
priors$bL=1 #lambda0, baseline rate
priors$aD=matrix(0,1,7)+5 #day effect dirichlet params
priors$aH=matrix(0,nrow=48,ncol=7)+1 #time of day effect dirichlet param
priors$z01=.01*10000
priors$z00=.99*10000   #z(t) event process

priors$z01 = .01*10000; priors$z00 = .99*10000;     # z(t) event process
priors$z10 = .25*10000; priors$z11 = .75*10000;     
priors$aE = 2000; priors$bE = 1/3;       # gamma(t), or NBin, for event # process

priors$MODE = 0;

sensorMMPP <- function(N,priors,ITERS,events,EQUIV){
  #Data (Ntimes x 7*Nweeks) matrix of count data (assumed starting Sunday)
  #priors
  #ITERS
  #EQUIV
  
  Niter<-ITERS[1]
  Nburn<-ITERS[2]
  Nplot<-ITERS[3]
  
  Z<-matrix(0,dim(N)[1],dim(N)[2])
  N0<-pmax(N,1)
  NE<-matrix(0,dim(N)[1],dim(N)[2]) 
  L<-(N+5)/2  
  M<-matrix(c(.999,.001,.5,.5),nrow=2) 
  xs <- seq(0,1,80)
  Nd<-7 
  Nh<-dim(N)[1]
  samples<-list()
  samples$L <- vector("list",Niter)
  samples$Z <- vector("list",Niter)
  samples$M <- vector("list",Niter)
  samples$N0 <- vector("list",Niter)
  samples$NE <- vector("list",Niter)
  samples$logp_NgLM <- vector("list", Niter)
  samples$logp_NgLZ <- vector("list",Niter)
  
  #initialize the samples to zero

    samples$L<-array(0,dim=c(dim(L)[1],dim(L)[2],Niter))
    samples$Z<-array(0,dim=c(dim(Z)[1],dim(Z)[2],Niter))
    samples$M<-array(0,dim=c(dim(M)[1],dim(M)[2],Niter))
    samples$N0<-array(0,dim=c(dim(N0)[1],dim(N0)[2],Niter))
    samples$NE<-array(0,dim=c(dim(NE)[1],dim(NE)[2],Niter))
  
  
  samples$logp_NgLM<-matrix(0,1,50)
  samples$logp_NgLZ<-matrix(0,1,50)
  
######### MAIN LOOP: MCMC FOR INFERENCE  ###########
for (iter in 1:Niter+Nburn){
print(iter)
L <- draw_L_N0(N0,priors,EQUIV);
res <-draw_Z_NLM(N,L,M,priors);#requires ":=" hack
  Z<-res$Z;
  N0<-res$N0;
  NE<-res$NE;
M <- draw_M_Z(Z,priors);


if (iter > Nburn){    # SAVE SAMPLES AFTER BURN IN
samples$L[,,iter-Nburn] = L
samples$Z[,,iter-Nburn] = Z   
samples$M[,,iter-Nburn] = M
samples$N0[,,iter-Nburn] = N0 
samples$NE[,,iter-Nburn] = NE
samples$logp_NgLM[iter-Nburn] = eval_N_LM(N,L,M,priors); #fix
samples$logp_NgLZ[iter-Nburn] = eval_N_LZ(N,L,Z,priors); #fix
}

# DISPLAY / PLOT CURRENT SAMPLES & AVERAGES
#mmppPlot(L,Z,N,events,100); title('MCMC Samples'); pause(.5);
#if (mod(iter,Nplot)==0 && iter > Nburn) {
#  mmppPlot(mean(samples.L(:,:,1:iter-Nburn),3), ...
#           mean(samples.Z(:,:,1:iter-Nburn),3), N, events,101); figure(101); title('Posterior Averages');      
c(logpC, logpGD, logpGDz) := logp(N,samples,priors,iter-Nburn,EQUIV)
logpC=logpC/log(2)
logpGD=logpGD/log(2)
logpGDz=logpGDz/log(2) 
#}
samples$logpC = logpC
samples$logpGD = logpGD
}


return(samples)
}


#### various distribution functions
dirpdf<-function(X,A){
  k<-length(X)
  if(k==1){
    p<-1
    return(p)
  }
  else{
    logp=sum((A-1)*log(X))-sum(lgamma(A))+lgamma(sum(A))
  
  p<-exp(logp)  
  return(p)
}
  }





poisslnpdf<-function(X,L){  		
lnp = -L -lgamma(X+1) +log(L)*X;
}
binpdf<-function(X,R,P){		#negative binomial distribution
lnp = lgamma(X+R)-lgamma(R)-lgamma(X+1)+log(P)*R+log(1-P)*X
p = exp(lnp)
}

nbinlnpdf<-function(X,R,P){		# log(neg binomial)
lnp = lgamma(X+R)-lgamma(R)-lgamma(X+1)+log(P)*R+log(1-P)*X
}

#logliklihood function for Poisson
loglikeP <- function (X,L){
  return -L - lgamma(X+1)+log(L)*X
}

#logliklihood function for negative binomial distribution
#pnbinom(q, size, prob, mu, lower.tail = TRUE, log.p = FALSE)

draw_Z_NLM <- function(N,L,M,prior){
N0 = N
NE = 0*N
Z=0*N
ep=1e-50
######## FIRST SAMPLE Z, N0, NE:
PRIOR <-M%^%100%*%as.vector(c(1,0))
po <-matrix(0,2,length(N)) 
p  <-matrix(0,2,length(N))
for (t in 1:length(N)){
if (N[t]!=-1){
  po[1,t] <- dpois(N[t],L[t])+ep;
  po[2,t] <- sum(dpois(0:N[t],L[t])*dnbinom(rev(0:N[t]),priors$aE,priors$bE/(1+priors$bE)))+ep;
}
  else {po[1,t]<-1
        po[2,t]<-1}
}

# Compute forward (filtering) posterior marginals
p[,1] <- PRIOR*po[,1] 
p[,1] <-p[,1]/sum(p[,1]);
for (t in 2:length(N)){ 
  p[,t] <- (M%*%p[,t-1])*po[,t]
  p[,t]<-p[,t]/sum(p[,t])  
}


# Do backward sampling
for (t in rev(1:length(N))){
  if (runif(1) >  p[1,t]){                          # if event at time t
    if (N[t]!=-1){
        Z[t] = 1 
        # likelihood of all possible event/normal combinations (all possible values of N(E)
        ptmp = dpois(0:N[t],L[t],log=TRUE) + dnbinom(rev(seq(0,N[t],1)),priors$aE,priors$bE/(1+priors$bE),log=TRUE)
        ptmp<-ptmp-max(ptmp)
        ptmp=exp(ptmp)
        ptmp=ptmp/sum(ptmp)
        N0[t] = min(which(cumsum(ptmp) >= runif(1)))-1; # draw sample of N0
        NE[t]=N[t]-N0[t]                       # and compute NE
    }
  else{
        Z[t]=1
        N0[t]=rpois(1,L[t])
        NE[t]=rnbinom(1,priors$aE,priors$bE/(1+priors$bE));
      }
  }                
  else{
    if (N[t]!=-1){
      Z[t] = 0
      N0[t] = N[t]
      NE[t]=0             # no event at time t
      }
    else{
      Z[t]=0
      N0[t]=rpois(1,L[t])
      NE[t]=0
    }
}

ptmp = matrix(0,2,1)
ptmp[Z[t]+1] <- 1    # compute backward influence
if (t>1) {
  p[,t-1] <- p[,t-1]*(t(M)%*%ptmp) 
  p[,t-1] <- p[,t-1]/sum(p[,t-1])
  }
}

 out<-list()
 out$Z<-Z
 out$N0<-N0
 out$NE<-NE
 #out$p<-p
 #out$po<-po
 return(out)
}


draw_M_Z <- function(Z,prior){
  n01 = length(which(Z[1:length(Z)-1]==0 & Z[2:length(Z)]==1))
  n0 = length(which(Z[1:length(Z)-1]==0))
  n10 = length(which(Z[1:length(Z)-1]==1 & Z[2:length(Z)==0]))
  n1 = length(which(Z[1:length(Z)-1]==1))
  z0 = rbeta(1,n01+prior$z01,n0-n01+prior$z00)
  z1 = rbeta(1,n10+prior$z10,n1-n10+prior$z11)
  M = t(matrix(c(1-z0, z1, z0,1-z1),nrow=2,ncol=2))
  return(M)
}
     

draw_L_N0<- function(N0,prior,EQUIV){
Nd=7; 
Nh=dim(N0)[1]
#1st: OVERALL AVERAGE RATE
if (prior$MODE){
L0 = (sum(N0)+prior$aL)/(length(N0)+prior$bL)
} else{
  L0 = rgamma(1,shape=sum(N0)+prior$aL,scale=1/(length(N0)+prior$bL))
}
L = matrix(0,dim(N0)[1],dim(N0)[2]) + L0;
# 2nd: DAY EFFECT
D = matrix(0,1,Nd)
for(i in 1:length(D)){
alpha =  sum(N0[,seq(i,dim(N0)[2],7)])+prior$aD[i];
if (prior$MODE) 
  D[i] = (alpha-1)           #mode of Gamma(a,1) distribution
else            
  D[i] = rgamma(1,alpha,scale=1)
}
# 3rd: TIME OF DAY EFFECT
A = matrix(0,Nh,Nd);

for (tau in 1:(dim(A)[2])){
for (i in 1:dim(A)[1]){
alpha = sum(N0[i,seq(tau,dim(N0)[2],7)])+prior$aH[i]
if (prior$MODE) 
  A[i,tau] = (alpha-1)           # mode of Gamma(a,1) distribution
else            
  A[i,tau] = rgamma(1,alpha,scale=1)

}
}
# ENFORCE PARAMETER SHARING
if (EQUIV[1]==1){
D[1:7] = 1
} else if(EQUIV[1]==2){
D[c(1,7)] = mean(D[c(1,7)])
D[2:6]=mean(D[2:6])
D=D/mean(D)
} else if(EQUIV[1]==3){
D = D/mean(D)
}

###FIX THIS
# tau(t)
if(EQUIV[2]==1){
A[,1:7] = repmat(matrix(rowMeans(A)),1,dim(A)[2])
} else if (EQUIV[2]==2){
A[,c(1,7)] <- repmat(matrix(rowMeans(A[,c(1,7)])),1,2)

A[,2:6]<-repmat(matrix(rowMeans(A[,2:6])),1,5) 
} else if(EQUIV[2]==3){ A<-A
}

for (tau in 1:dim(A)[2]){ 
A[,tau]=A[,tau]/mean(A[,tau])
}

# COMPUTE L(t)
for (d in 1:dim(L)[2]){
for (t in 1:dim(L)[1]){ 
  dd=(d-1)%%7+1; 
  L[t,d] = L0*D[dd]*A[t,dd]; #fix this line
} 
}

return(L)
}

###Evaluation functions
logp<-function(N,samples,priors,iter,EQUIV){
#estimates the marginal likelihood of the data using the samples
  
  tmp<-samples$logp_NgLZ[1:iter]
  tmpm<-mean(tmp)
  temp<-tmp-tmpm
  logpGDz<-log(1/mean(1/exp(tmp)))+tmpm #Gelfand-Dey estimate
  
  tmp<-samples$logp_NgLZ[1:iter]
  tmpm<-mean(tmp)
  temp<-tmp-tmpm
  logpGD<-log(1/mean(1/exp(tmp)))+tmpm #Gelfand-Dey estimate, marginalizing over Z
  
  Lstar<-apply(samples$L,c(1,2),mean)
  Mstar<-apply(samples$M,c(1,2),mean)
  logp_LMgN<-matrix(0,1,iter)
  logp_LM <- eval_L_N0(Lstar,vector(),priors,EQUIV)+eval_M_Z(Mstar,0,priors)
  logp_NgLM <- eval_N_LM(N,Lstar,Mstar,priors)
  for (ii in 1:iter){
    logp_LMgN[ii]<-eval_L_N0(Lstar,samples$N0[,,ii],priors,EQUIV)+eval_M_Z(Mstar,samples$Z[,,ii],priors)
  }
  tmpm<-mean(exp(logp_LMgN))+tmpm
  logpC<-logp_NgLM+logp_LM-logp_LMgN #Chib estimate
  
}


eval_M_Z <- function(M,Z,prior){ #evaluate p(M|Z)
z1 = M[1,2]
z0 = M[2,1]
n01=0
n0=0
n10=0
n1=0 
if (length(Z)!=0){
n01 = sum(Z[1:length(Z)-1]==0 & Z[2:length(Z)]==1) 
n0=sum(Z[1:length(Z)-1]==0)
n10 =  sum(Z[1:length(Z)-1]==1 & Z[2:length(Z)]==0) 
n1=sum(Z[1:length(Z)-1]==1)
} else {n01<-0
n0<-0
n10<-0
n1<-0}  
logp <- log(pbeta(z0,n01+prior$z01,n0-n01+prior$z00)) + log(pbeta(z1,n10+prior$z10,n1-n10+prior$z11))
return(logp)
}
  

eval_L_N0 <- function(L,N0,prior,EQUIV){  # evaluate p(L | N0)
L0 = mean(L)
Nd = 7
Nh=dim(L)[1]
A<-matrix(0,Nh,Nd)
D<-rep(NA,Nd)
for (i in 1:Nd) {
  D[i] = mean(L[,i]/L0)
}
for (i in 1:Nd){
  for (j in 1:Nh){
    A[j,i] = L[j,i]/L0/D[i]
  }
}
logp = 0;
# ENFORCE PARAMETER SHARING
paD<-prior$aD; 
aD<-matrix(0,1,Nd); 
paH<-prior$aH;
dim(paH)
aH<-matrix(0,Nh,Nd);
if (length(N0)!=0){
  for (i in 1:Nd){
    aD[i] = sum(N0[,seq(i,dim(N0)[2],Nd)]) #fix this line
  }
for (i in 1:Nd){
  for (j in 1:Nh){ 
  aH[j,i] = sum(N0[j,seq(i,dim(N0)[2],Nd)])
}
}
  }
  
if (EQUIV[1]==1){ #d(t)
D = sum(D)
paD = sum(paD)
aD=sum(aD)
} else if (EQUIV[1]==2){
D = c(D[1]+D[7],sum(D[2:6])); 
paD=c(paD[1]+paD[7],sum(paD[2:6]))
aD=c(aD[1]+aD[7],sum(aD[2:6]));
} else if (EQUIV[1]==3){
  D = D; paD = paD; paH=paH;
}

if(EQUIV[2]==1){ # tau(t)
A<-matrix(rowSums(A)/Nd)
aH<-matrix(rowSums(aH))
paH<-matrix(rowSums(paH))
} else if(EQUIV[2]==2){
A = matrix(c((A[,1]+A[,7])/2,rowSums(A[,2:6])/5))
aH = matrix(c(aH[,1]+aH[,7],rowSums(aH[,2:6])))
paH = matrix(c(paH[,1]+paH[,7],rowSums(paH[,2:6])))
} else if(EQUIV[2]==3){
  A<-A
  aH=aH
  paH=paH
}

logp = logp + log(pgamma(L0,sum(sum(N0))+prior$aL,1/(length(N0)+prior$bL)));
logp = logp + log(dirpdf(D/Nd,aD + paD));

for (i in 1:dim(A)[2]){
logp = logp + log(dirpdf(A[,i]/Nh,aH[,i]+paH[,i]))
}
return(logp)
}

eval_N_LM<-function(N,L,M,prior) { 	# evaluate p(N | L,M)
  PRIOR <-M%^%100%*%as.vector(c(1,0))
  po <-matrix(0,2,length(N)); 
  p  <-matrix(0,2,length(N));
for (t in 1:length(N)){
if (N[t]!=-1){
po[1,t] = dpois(N[t],L[t]);      
po[2,t] = sum(dpois(0:N[t],L[t])*dnbinom(rev(0:N[t]),prior$aE,prior$bE/(1+priors$bE)))

}
  else{ po[1,t]=1
        po[2,t]=1
  }
}

p[,1] = PRIOR*po[,1]
sp=sum(p[,1]) 
logp = log(sp);
p[,1]=p[,1]/sp;
for (t in 2:length(N)){
p[,t] = (M%*%p[,t-1])*po[,t]
sp=sum(p[,t])
logp = logp + log(sp); 
p[,t]=p[,t]/sp;
}
  return(logp)
}

eval_N_LZ <- function(N,L,Z,prior){ 	#evaluate p(N|L,Z)
logp = 0;
for (t in 1:length(N)){
if (N[t]!=-1){
if (Z[t]==0){
  logp = logp + log(dpois(N[t],L[t]))
}
else{          
  logp = logp + log(sum(dpois(0:N[t],L[t])*dnbinom(rev(0:N[t]),prior$aE,prior$bE/(1+prior$bE))))
}
}
}
return(logp)
}

':=' = function(lhs, rhs) {
  frame = parent.frame()
  lhs = as.list(substitute(lhs))
  if (length(lhs) > 1)
    lhs = lhs[-1]
  if (length(lhs) == 1) {
    do.call(`=`, list(lhs[[1]], rhs), envir=frame)
    return(invisible(NULL)) }
  if (is.function(rhs) || is(rhs, 'formula'))
    rhs = list(rhs)
  if (length(lhs) > length(rhs))
    rhs = c(rhs, rep(list(NULL), length(lhs) - length(rhs)))
  for (i in 1:length(lhs))
    do.call(`=`, list(lhs[[i]], rhs[[i]]), envir=frame)
  return(invisible(NULL)) }
     



mmPPlot<-function(L,Z,N,TRUTH,FIG,RANGE){
  if(!exists('RANGE')){
    RANGE<-1:length(Z)
  }
  
  
  
}
