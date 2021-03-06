# lm 16.09.15

# load required packages
library(hadleyverse)
library(foreign)
library(haven) # assuming stata13 files
library(checkpoint)
library(ProjectTemplate)
library(explainr)
library(magrittry
library(psych)
library(MASS)
library(arm)
library(broom)
  

# set wd
setwd("~/studium/TUT/econometric (phd) - TES9130/R/econometrics - TES9130/econometrics-TES9130")

# read in data
Males<-read_dta("Males.dta")
summary(Males)
View(Males)


# Visualize dataset
pairs(Males)
## This error can occur in Rstudio simply because your "Plots" pane is just barely too small. Try zooming your "Files, Plots, Packages, Help, Viewer" and see if it helps!


# Histogram 
discrete.histogram(Males$SCHOOL)
hist(Males$SCHOOL)
hist(Males$SCHOOL, freq = F)
lines(density(Males$SCHOOL), col = 4)

# Exp Wage
Wage<-Males$WAGE
Males$ExpWage<- exp(Wage)

hist(Males$WAGE)
hist(Males$ExpWage)


## or via ggplot2
# Hist. Wage
w0 = ggplot(Males, aes(x=Wage), geom = "blank") +   
  geom_line(aes(y = ..density.., colour = 'Empirical'), stat = 'density') +  
  stat_function(fun = dnorm, aes(colour = 'Normal')) +                       
  geom_histogram(aes(y = ..density..), alpha = 0.4) +  
  labs(title="Histogram for Wage") 
  scale_colour_manual(name = 'Density', values = c('red', 'blue'))
print(w0)

# Hist. Exp Wage
w1 = ggplot(Males, aes(x=ExpWage), geom = "blank") +   
  geom_line(aes(y = ..density.., colour = 'Empirical'), stat = 'density') +  
  stat_function(fun = dnorm, aes(colour = 'Normal')) +                       
  geom_histogram(aes(y = ..density..), alpha = 0.4) +  
  labs(title="Histogram for Expo Wage") 
  scale_colour_manual(name = 'Density', values = c('red', 'blue'))
print(w1)


# Hist School
s0 = ggplot(Males, aes(x=SCHOOL), geom = "blank") +   
  geom_line(aes(y = ..density.., colour = 'Empirical'), stat = 'density') +  
  stat_function(fun = dnorm, aes(colour = 'Normal')) +                       
  geom_histogram(aes(y = ..density..), alpha = 0.4,binwidth=1) +  
  labs(title="Histogram for School") + 
    scale_colour_manual(name = 'Density', values = c('red', 'blue'))
print(s0)
## discrete variables influence the distribution function
## proposed workarounds: 1) transform variables or 2) play with bin_geom 3) use lattice to plot it


# estimnate OLS regression 
names(Males)
lm1<- lm(WAGE ~ EXPER + SCHOOL + UNION + MAR + BLACK, data=Males) 
summary (lm1)
## output is correct

# For precise effect size use exp(a)~1+a i.e. a=exp(a)-1
# we replace the parameter estimate with the exponant -1 to get the more exact effect
# calulate exact the log and the exp function
# the exponent of the exact calculation should be larger
lm1.exactlog<-exp(lm1$coefficients)-1

# row bind the approximation and the exact log beta_hat
beta_hat.comparison<-rbind(lm1$coefficients, lm1.exactlog)
beta_hat.comparison

# III GENERATE WAGE PREDICTION IN LEVELS - THE RETRANSFORMATION PROBLEM ON LOG-LINEAR MODEL //
# Note that exp(E(ln y) is not equal to E(y), BUT E(y|x)=exp(x'b)E(exp(u))
# 1) Assuming the error term, u, is normally distributed u=N(0, sigma^2), then E(y|x)=exp(x'b)exp(0.5 s^2)
# find exact number in levels (in Dollar) not in log Dollars

# "old way"
lyhat_mean<-mean(fitted.values(lm1))
lyhat_sd<-sd(fitted.values(lm1))
lyhat_min<-min(fitted.values(lm1))
lyhat_max<-max(fitted.values(lm1))
cbind(lyhat_mean, lyhat_sd, lyhat_min, lyhat_max)

# dplyr way 
df<- as.data.frame(predict.lm(lm1)) 
names(df)[names(df)=="predict.lm(lm1)"] <- "lnyhat" # rename columnnam

lnyhat.df <-df %>%
  summarise(length(lnyhat),
            mean = mean(lnyhat), 
            st.dev. = sd(lnyhat),
            min = min(lnyhat),
            max = max (lnyhat))
            

# assuming normally distributed error terms we can have 0.5. should work over the predict function in R
rse<-summary(lm1)$sigma # extract residual standard error for simplicity
yhatnormal<-exp(lnyhat.df$mean)*exp((0.5)*rse^2)
yhatnormal
## not exactly the same results as stata!

# 2) Duan(1983) approach: apply a weaker assumption of iid error term and estimate E(exp(u))=avg(exp(u_hat)), then E(y|x)=exp(x'b)avg(exp(u_hat))
# predict residuals u_ha
lnyhat = predict(lm1, data.frame(Males)) ## update as the code line was missing
lnyhat
summary(lnyhat)

e<-(lm1$residuals)
summary(e)
Duan <- (exp(lm1$residuals))
summary(Duan)                 ## Same results as in STATA

yhat_Duan<- (exp(lnyhat)*mean(lnyhat))
summary(yhat_Duan)            ## Not same results as in STATA

### For comparison generate the wrong prediction in levels using exp(E(ln y)), generate the WAGE in levels and compare with the results above
yhat_wrong<- exp(lnyhat)  
summary(yhat_wrong)           ## Same results as in STATA
summary(WAGE_lev)
summary(yhatnormal)
summary(yhat_Duan)
summary(yhat_wrong)


### IV ESTIMATE OLS WITH INTERACTION BETWEEN SCHOOLING AND MINORITY 
MINORITY<-ifelse(Males$BLACK==1 | Males$HISP==1, 1,0)
summary(MINORITY)
MINSCH<-Males$SCHOOL*MINORITY
summary(MINSCH)          ## Same results like in STATA

# Generate regression with interaction MINORITY*SCHOOL

##  xi: gives me interaction term and the respective dummyies
## regress WAGE EXPER UNION MAR i.MINORITY*SCHOOL 

## additive interaction
names(Males)
lm2<- lm(WAGE ~ EXPER + UNION + MAR + MINORITY * SCHOOL ,  data=Males) 
summary(lm2)
confint.lm(lm2)

## Same results like in STATA

# Generate interaction manually
## lm3<- lm(WAGE ~ EXPER + UNION + MAR + MINSCH ,  data=Males) # cannot work as term a:x is an interaction term in the lm function, which gives the difference in slopes
## compared with the reference category
### Not sure how to generate the interaction manually
lm3 <- lm(WAGE ~ EXPER + UNION + MAR + MINORITY*(SCHOOL), data=Males)
summary(lm3)
lm3$coef
confint.lm(lm3)
### Another way to generate the interaction but the output from lm3 and lm3a is different. WHY?
lm3a <- lm(WAGE ~ EXPER + UNION + MAR + SCHOOL:MINORITY, data=Males)
summary(lm3a)
lm3a$coef


library(car) ## for the ANOVA function
plot(lm2)                    ## show the diagnostics on the screen
Anova(lm2) 
Anova(lm1,lm2)

library(effects)
eff_cf <- effect("MINORITY:SCHOOL", lm2)
eff_cf
print(plot(eff_cf, multiline=TRUE))
# All effects
eff.pres <- allEffects(lm2, xlevels=50)
plot(eff.pres)

# Calculate average marginal effect manually
cf1 <- summary(lm2)$coef
me_SCHOOL <- cf1['SCHOOL',1] + cf1['MINORITY:SCHOOL',1]*MINORITY # MEs of SCHOOL given MINORITY
me_MINORITY <- cf1['MINORITY',1] + cf1['MINORITY:SCHOOL',1]*Males$SCHOOL # MEs of MINORITY given SCHOOL
mean(me_SCHOOL) # average marginal effects of SCHOOL
mean(me_MINORITY) # average marginal effects of MINORITY

# Variance-Covariance Matrix for a Fitted Model
v <- vcov(lm2)
v
## same as in STATA

# standard error for interaction
sqrt(v['SCHOOL','SCHOOL'] + (mean(MINORITY)^2)*v['MINORITY:SCHOOL','MINORITY:SCHOOL'] + 2*mean(MINORITY)*v['SCHOOL','MINORITY:SCHOOL']) 

# STATA lincom procedure
## Lincomp procedure not modelled so far. "multcomp" might help. Gelman has in "Data Analysis Using Regression and Multilevel/Hierarchical Models" similar exercises

# V TEST FOR MODEL (MIS)SPECIFICATION
# RAMSEY (1969) RESET TEST (CONTROLLING FUNCTIONAL FORM AND OMITTED VARIABLES)
library(lmtest)
lm1 <- lm(WAGE ~ SCHOOL + EXPER + UNION + MAR + BLACK, data=Males)
lm1
resettest(lm1, power=2:3, type="fitted")
##### OUTPUT DIFFERENT FROM STATA

##### drop yhat yhat2 yhat3 
yhat = predict(lm1, data.frame(Males))
yhat    
summary(yhat)
### Generate yhat2 yhat3 yhat4
yhat2<-yhat^2
summary(yhat2)
yhat3<-yhat^3
summary(yhat3)
yhat4<-yhat^4
summary(yhat4)

### Regression with yhat2 yhat3 yhat4
lm5 <- lm(WAGE ~ SCHOOL + EXPER + UNION + MAR + BLACK + yhat2 + yhat3 + yhat4, data=Males)
lm5
lm5$coef #### Same output as in STATA
lmReduced <- update(lm5, .~. - yhat2 - yhat3 - yhat4)
anova(lm5, lmReduced,test= 'F')      ### SAME OUTPUT AS IN STATA


# Obtain AIC and BIC
lm3<-lm(WAGE ~ SCHOOL + EXPER + EXPER2 + UNION + MAR + BLACK ,  data=Males)
summary(lm3)
AIC(lm3)
stopifnot(all.equal(AIC(lm3),AIC(logLik(lm3))))
BIC(lm3)  

lm4 <- update(lm3, . ~ . -EXPER2)
summary(lm4)
AIC(lm3, lm4)
BIC(lm3, lm4)
## marginal difference to STATA. Results lead to the same conclusion


# Test Joint hypotheses with F-test
lm3<-lm(WAGE ~ SCHOOL + EXPER + EXPER2 + UNION + MAR + BLACK ,  data=Males)
summary(lm3)
lm3$coef

# Test restricted and unrestricted model with F-test
lm3<-lm(WAGE ~ SCHOOL + EXPER + EXPER2 + UNION + MAR + BLACK ,  data=Males)
lm3
lm3$coef 
lmReduced <- update(lm3, .~. - EXPER - SCHOOL)
anova(lm3, lmReduced,test= 'F')    ####F=298,15 


lm3<-lm(WAGE ~ SCHOOL + EXPER + EXPER2 + UNION + MAR + BLACK ,  data=Males)
lm3
lm3$coef 
lmReduced <- update(lm3, .~. - EXPER2)
anova(lm3, lmReduced,test= 'F')  #### SAME RESULTS AS IN STATA F=16.027 AND Pr(F)=.00006337


# VI MULTICOLLINEARITY 
# Since variable Experience is defined: EXPER=AGE-6, then generate variable AGE=EXPER+6
AGE<-Males$EXPER+6
summary(AGE)

# Note that regressing both AGE and EXPER on logwage leads to exact multicollinearity and AGE is dropped
lm3<-lm(WAGE ~ SCHOOL + AGE + UNION + MAR + BLACK - EXPER,  data=Males)
lm3
lm3$coef 


# Calculate Variance Inflation Factors (alternatively Tolerance=1/VIF) for explanatory variables. Note that VIF above 10 or Tolerance below 0.1 are signs of warning.
library(car)
lm1 <- lm(WAGE ~ SCHOOL + EXPER + UNION + MAR + BLACK, data=Males)
lm1
lm1$coef

vif(lm(WAGE ~ SCHOOL + EXPER + UNION + MAR + BLACK, data=Males))   ###SAME OUTPUT AS IN STATA FOR VIF

##### FIND THE TOLERANCE VIF AS LAST TASK#####
##### Last commit
