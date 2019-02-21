# Title     : TODO
# Objective : TODO
# Created by: lenovo
# Created on: 2019/2/2
d=read.csv("precessed_data.csv")
m=as.matrix(d['count'])
N=matrix(m,48,64)
e=matrix(0,48,64)
source("MMPP.R")
samples <- sensorMMPP(N[,1:63], priors, c(50, 10, 1), e, c(3, 3))
write.csv(res2,"res_mat.csv",row.names = FALSE)
d=read.csv("res_mat.csv",header = TRUE)
all(array(as.matrix(d),c(48,64,50))==res)
zmean=apply(samples$Z,c(1,2),mean)
plot(as.vector(zmean))
plot(as.vector(samples$Z[,,50]))
as.Date()

