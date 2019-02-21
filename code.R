# Title     : TODO
# Objective : TODO
# Created by: lenovo
# Created on: 2019/2/3
#coding=utf-8
d=read.csv("precessed_data.csv")
m=as.matrix(d['count'])
N=matrix(m,48,64)
e=matrix(0,48,64)
source("MMPP.R")
samples <- sensorMMPP(N[,1:63], priors, c(50, 10, 1), e, c(3, 3))
zmean=apply(samples$Z,c(1,2),mean)
zm=as.vector(zmean)
names(zm)=d['time'][1:3024,1]
plot(zm[1:48],type='l',xlab="时间",xaxt='n',ylab="第一天增加事件发生概率")
axis(1,1:length(zm[1:48]),names(zm[1:48]))