mydata <- ames_housing_data
mydata$TotalFloorSF <- mydata$FirstFlrSF + mydata$SecondFlrSF
mydata$TotalSqftCalc <- mydata$BsmtFinSF1+mydata$BsmtFinSF2+mydata$GrLivArea
mydata$HouseAge <- mydata$YrSold - mydata$YearBuilt
mydata$QualityIndex <- mydata$OverallQual * mydata$OverallCond
mydata$logSalePrice <- log(mydata$SalePrice)
str(mydata)
mydataclean<-mydata[-c(2446,1064,2451,433,16,2667,424,2738,1319,47),]
mydata_selected<- subset(mydataclean,GrLivArea<4000 & !(Zoning %in% c('A','C','I','FV')) & SaleCondition =='Normal')
# explore categorical variables: LotShape, Neighborhood, BldgType

library(ggplot2)
ggplot(data = mydata_selected) +
  geom_bar(mapping = aes(x = LotShape))
ggplot(mydata_selected, aes(x=LotShape, y=SalePrice)) + 
  geom_point(color="blue", shape=1) +
  ggtitle("Scatter Plot of Lotshape~Saleprice") +
  theme(plot.title=element_text(lineheight=0.8, face="bold", hjust=0.5))

ggplot(data = mydata_selected) +
  geom_bar(mapping = aes(x = Neighborhood))

ggplot(data = mydata_selected) +
  geom_bar(mapping = aes(x = BldgType))
ggplot(mydata_selected, aes(x=BldgType, y=SalePrice)) + 
  geom_point(color="blue", shape=1) +
  ggtitle("Scatter Plot of BldgType~Saleprice") +
  theme(plot.title=element_text(lineheight=0.8, face="bold", hjust=0.5))
#generate summaries
summary(mydata_selected[mydata_selected$LotShape=='IR1','SalePrice'])

mydata_selected$LotIR1<-ifelse(mydata_selected$LotShape=='IR1',1,0)
mydata_selected$LotIR2<-ifelse(mydata_selected$LotShape=='IR2',1,0)
mydata_selected$LotIR3<-ifelse(mydata_selected$LotShape=='IR3',1,0)
mydata_selected$LotReg<-ifelse(mydata_selected$LotShape=='Reg',1,0)

mydata_selected$logSalePrice<-log(mydata_selected$SalePrice)
variables<-c('SalePrice','logSalePrice','OverallQual','OverallCond','GrLivArea','FullBath','HalfBath','HouseAge','GarageArea',
                'LotFrontage','LotArea','BsmtUnfSF','TotalSqftCalc','BedroomAbvGr','TotRmsAbvGrd','WoodDeckSF',
             'OpenPorchSF','LotIR1','LotIR2','LotIR3')
variablesadd<-c('logSalePrice','OverallQual','GrLivArea','FullBath','HalfBath','HouseAge','GarageArea',
             'LotFrontage','LotArea','BsmtUnfSF','TotalSqftCalc','BedroomAbvGr','TotRmsAbvGrd','WoodDeckSF',
             'OpenPorchSF','LotIR1','LotIR2','LotIR3','OverallCond','QualityIndex')

datam<-mydata_selected[variables]
datam<-na.omit(datam) 
datam1<-mydata_selected[variablesadd]
datam1<-na.omit(datam1)


set.seed(123)
datam$u <- runif(n=dim(datam)[1],min=0,max=1);
datam1$u <- runif(n=dim(datam)[1],min=0,max=1);
# Create train/test split;
train.df <- subset(datam, u<0.70);
train1.df <- subset(datam1, u<0.70);
test.df  <- subset(datam, u>=0.70);
# Define the upper model as the FULL model
upper.lm <- lm(logSalePrice ~ .-u,data=train.df);
summary(upper.lm)

# Define the lower model as the Intercept model
lower.lm <- lm(logSalePrice ~ 1,data=train.df);

# Need a SLR to initialize stepwise selection
sqft.lm <- lm(logSalePrice ~ TotalSqftCalc,data=train.df);
summary(sqft.lm)

library(MASS)

# Call stepAIC() for variable selection
forward.lm <- stepAIC(object=lower.lm,scope=list(upper=formula(upper.lm),lower=formula(lower.lm)),
                      direction=c('forward'));
summary(forward.lm)

backward.lm <- stepAIC(object=upper.lm,direction=c('backward'));
summary(backward.lm)

stepwise.lm <- stepAIC(object=sqft.lm,scope=list(upper=formula(upper.lm),lower=~1),
                       direction=c('both'));
summary(stepwise.lm)

junk.lm <- lm(logSalePrice ~ OverallQual + OverallCond + QualityIndex + GrLivArea + TotalSqftCalc, data=train1.df)
summary(junk.lm)
library(car)
library(car)
sort(vif(forward.lm),decreasing=TRUE)
sort(vif(junk.lm),decreasing=TRUE)

AIC(forward.lm)
BIC(forward.lm)
AIC(junk.lm)
BIC(junk.lm)

mean((forward.lm$residuals)^2)
mean((junk.lm$residuals)^2)
mean(abs(forward.lm$residuals))
mean(abs(junk.lm$residuals))

forward.test <- predict(forward.lm,newdata=test.df)
junk.test <- predict(junk.lm,newdata=test.df)
forwardresidual<-forward.test-test.df$logSalePrice
junkresi<-junk.test-test.df$logSalePrice

mean((forwardresidual)^2)
mean((junkresi)^2)
mean(abs(forwardresidual))
mean(abs(junkresi))

# Abs Pct Error
trueresidual<-train.df$SalePrice-exp(forward.lm$fitted.values)
truejunkresidual<-train.df$SalePrice-exp(junk.lm$fitted.values)


forward.pct <- abs(trueresidual)/train.df$SalePrice;
junk.pct<-abs(truejunkresidual)/train.df$SalePrice

# Assign Prediction Grades;
forward.PredictionGrade <- ifelse(forward.pct<=0.10,'Grade 1: [0.0.10]',
                                  ifelse(forward.pct<=0.15,'Grade 2: (0.10,0.15]',
                                         ifelse(forward.pct<=0.25,'Grade 3: (0.15,0.25]',
                                                'Grade 4: (0.25+]')
                                  )					
)

forward.trainTable <- table(forward.PredictionGrade)
forward.trainTable/sum(forward.trainTable)

junk.PredictionGrade <- ifelse(junk.pct<=0.10,'Grade 1: [0.0.10]',
                                  ifelse(junk.pct<=0.15,'Grade 2: (0.10,0.15]',
                                         ifelse(junk.pct<=0.25,'Grade 3: (0.15,0.25]',
                                                'Grade 4: (0.25+]')
                                  )					
)

junk.trainTable <- table(junk.PredictionGrade)
junk.trainTable/sum(junk.trainTable)


# Test Data
# Abs Pct Error
forward.testPCT <- abs(test.df$SalePrice-exp(forward.test))/test.df$SalePrice;

junk.testPCT <- abs(test.df$SalePrice-exp(junk.test))/test.df$SalePrice


# Assign Prediction Grades;
forward.testPredictionGrade <- ifelse(forward.testPCT<=0.10,'Grade 1: [0.0.10]',
                                      ifelse(forward.testPCT<=0.15,'Grade 2: (0.10,0.15]',
                                             ifelse(forward.testPCT<=0.25,'Grade 3: (0.15,0.25]',
                                                    'Grade 4: (0.25+]')
                                      )					
)

forward.testTable <-table(forward.testPredictionGrade)
forward.testTable/sum(forward.testTable)

junk.testPredictionGrade <- ifelse(junk.testPCT<=0.10,'Grade 1: [0.0.10]',
                                      ifelse(junk.testPCT<=0.15,'Grade 2: (0.10,0.15]',
                                             ifelse(junk.testPCT<=0.25,'Grade 3: (0.15,0.25]',
                                                    'Grade 4: (0.25+]')
                                      )					
)

junk.testTable <-table(junk.testPredictionGrade)
junk.testTable/sum(junk.testTable)

anova(forward.lm)

finalm<-lm(data=datam, logSalePrice~OverallQual+TotalSqftCalc+LotArea+HouseAge+OverallCond
           +BsmtUnfSF+GarageArea+GrLivArea+LotFrontage)
summary(finalm)
library(lessR)
Model(data=datam, logSalePrice~OverallQual+TotalSqftCalc+LotArea+HouseAge+OverallCond
      +BsmtUnfSF+GarageArea+GrLivArea+LotFrontage)

















