library(devtools)
library(goldeneye)
library(readr)
PTS <- read_csv("PATIENTST1.csv")

#PART 1: COMBINING TABLES  FROM MIMIC-III RELATIONAL DATABASE 
####################################################
library(sqldf)
DCODES <- read_csv("DRGCODEST1.csv")
DCODES_NEW <- sqldf ("SELECT SUBJECT_ID, DRG_SEVERITY, 
                     GROUP_CONCAT(DRG_CODE)
                     DRG_JOIN 
                     FROM DCODES   
                     GROUP BY SUBJECT_ID
                     ")
#Aggregate  Drug codes into one entry (=one instance) per SUBJECT_ID the candidate key,  
#######################################################

DIAGNOSES_ICD <- read_csv("DIAGNOSES_ICD.csv")
DIAGNOSES_NEWCODES <- sqldf ("SELECT SUBJECT_ID, 
                             GROUP_CONCAT(ICD9_CODE)
                             ICD9_CODES 
                             FROM DIAGNOSES_ICD   
                             GROUP BY SUBJECT_ID
                             ")
##########################################################
ADMISSIONS <- read_csv("ADMISSIONS.csv")
ADMIN_NEW <- sqldf ("SELECT DISTINCT SUBJECT_ID, ETHNICITY, HOSPITAL_EXPIRE_FLAG as DEATH
                    FROM ADMISSIONS")
##########################################################
PROC <- read.csv("PROCEDURES_ICD.csv")
PROC_NEW <- sqldf ("SELECT SUBJECT_ID, 
                   GROUP_CONCAT(ICD9_CODE)
                   ICD9_CODES 
                   FROM PROC   
                   GROUP BY SUBJECT_ID
                   ")
dim(PROC_NEW)
###########################################################
MIMIC_DAMI2 <- sqldf("SELECT a.SUBJECT_ID, a.GENDER as P_GENDER, a.DOB as P_DOB, c.DRG_JOIN as DRUG_CODES, c.DRG_SEVERITY as DRG_SEV
                     FROM PTS as a, DCODES_NEW as c
                     WHERE a.SUBJECT_ID = c.SUBJECT_ID
                     ")
MIMIC2_DAMI2 <- sqldf("SELECT a.SUBJECT_ID, a.P_GENDER, a.P_DOB, a.DRUG_CODES, a.DRG_SEV, b.ICD9_CODES as ICD9_CODES
                      FROM MIMIC_DAMI2 as a, DIAGNOSES_NEWCODES as b
                      WHERE a.SUBJECT_ID = b.SUBJECT_ID
                      ")

MIMIC3_DAMI2 <- sqldf("SELECT a.*, b.ETHNICITY as ETHN, b.DEATH as DEATH
                      FROM MIMIC2_DAMI2 as a, ADMIN_NEW as b
                      WHERE a.SUBJECT_ID = b.SUBJECT_ID")

###########################################################
#PART 2: CREATE LIST OF CODES FOR "ADE PRESENT" AND IDENTIFY CLASSIFICATION COLUMN

ff = function(x, patterns, replacements = patterns, fill = NA, ...)
{
  stopifnot(length(patterns) == length(replacements))
  
  ans = rep_len(as.character(fill), length(x))    
  empty = seq_along(x)
  
  for(i in seq_along(patterns)) {
    greps = grepl(patterns[[i]], x[empty], ...)
    ans[empty[greps]] = replacements[[i]]  
    empty = empty[!greps]
  }
  
  return(ans)
}

ADE_CODES <- c('780','990','782','783','784','785','786','787','788',	
               '789','790','791','792','793','794','795', '796','797','798','799',
               '990','991','992','993', '994','995')	

ADE_ANS <- c('yes','yes','yes','yes','yes','yes','yes','yes','yes','yes','yes',
             'yes','yes','yes','yes','yes','yes','yes','yes','yes','yes',
             'yes','yes','yes','yes','yes')

ADE_YESNO <- ff(MIMIC3_DAMI2$ICD9_CODES, ADE_CODES, ADE_ANS,
                fill = "no")
#change to matrix                             
ADEYN_MX <- matrix(ADE_YESNO)
#change to data frame
ADEYN_TB <- as.data.frame(ADEYN_MX)
# add this to your mimic table 
MIMIC3_DAMI2$TF <- ADEYN_TB$V1
names(MIMIC3_DAMI2) <- c("SUBJECT_ID", "GENDER", "DOB", "DRUGS", "DRG_SEV", "ICD9_CODES", "ETHNICITY", "DEATH","ADE_PRESENT")           

#########################################
#NO ICD9 codes
MIMIC3_DAMI2$ICD9_CODES <- NULL 
MIMIC3_DAMI2_FINAL <- MIMIC3_DAMI2[,2:8]

############################################################
# PART 3: MANAGE MISSING VALUES
#changed the string to NA so it can be identified as such
MIMIC3_DAMI2_FINAL$ETHNICITY[MIMIC3_DAMI2_FINAL$ETHNICITY == "UNKNOWN/NOT SPECIFIED"] <- NA
#changed NA to 0 since that is what most have present value have (replace by most commong variable)
MIMIC3_DAMI2_FINAL$DRG_SEV[is.na(MIMIC3_DAMI2_FINAL$DRG_SEV)] <- 0
#remove NA 
MIMIC3_DAMI2_NOMISS <- na.omit(MIMIC3_DAMI2_FINAL)

MIMIC3_DAMI2_NOMISS$ETHNICITY <- as.factor(MIMIC3_DAMI2_NOMISS$ETHNICITY)
MIMIC3_DAMI2_NOMISS$GENDER <- as.factor(MIMIC3_DAMI2_NOMISS$GENDER)
MIMIC3_DAMI2_NOMISS$DOB <- as.numeric(as.factor(MIMIC3_DAMI2_NOMISS$DOB))
MIMIC3_DAMI2_NOMISS$DRUGS <- as.numeric(as.factor(MIMIC3_DAMI2_NOMISS$DRUGS))

#check with how many missing values there are per attribute
apply(MIMIC3_DAMI2_NOMISS,2,function(x){sum(is.na(x))})
dim(MIMIC3_DAMI2_NOMISS)
View(MIMIC3_DAMI2_NOMISS)

#Class distribution 
table(MIMIC3_DAMI2_NOMISS$ADE_PRESENT)
###############################################################
# train and test set with 80/20 ratio
# ------------------------
set.seed(113)
train.idx <- sample(1:nrow(MIMIC3_DAMI2_NOMISS), size = 0.8 * nrow(MIMIC3_DAMI2_NOMISS), replace = FALSE)

train.set <- MIMIC3_DAMI2_NOMISS[train.idx,]
test.set <- MIMIC3_DAMI2_NOMISS[-train.idx,]


##########################################################
# RANDOM FOREST 
library(randomForest)
# randomForest(formula, data, ntree, mtry, importance, nodesize)
rforest.model <- randomForest(ADE_PRESENT ~ ., data = train.set, ntree = 100, importance = TRUE)
rforest.pred <- predict(rforest.model, newdata = test.set, type = "response") # use type = "prob" for probability
table(Predictions = rforest.pred, Actual = test.set$ADE_PRESENT)
#accuracy
mean(rforest.pred == test.set$ADE_PRESENT)

library("caret")
# Precision / Positive Predictive Value
rf.precision <- posPredValue(as.factor(rforest.pred), test.set$ADE_PRESENT)
print(rf.precision)

# Recall / Sensitivity
rf.recall <- sensitivity(as.factor(rforest.pred), test.set$ADE_PRESENT)
print(rf.recall)

# variable importance
rforest.model$importance

# Sort according to importance (Decrease in Accuracy or Gini)
rforest.model$importance[order(rforest.model$importance[,3], decreasing = TRUE),]

# plot variable importance according to decrease in accuracy 
imp.score <- sort(rforest.model$importance[,3], decreasing = FALSE)
par(las=2, oma = c(1,6,1,0), cex = 0.8)
barplot(imp.score, horiz = TRUE, col = "red", main = "Variable Importance")

############################################################
#Goldeneye
GOL_atts <- goldeneye(data = test.set, classifier = randomForest,  
                      real.class.name = "ADE_PRESENT", goodness.function = fidelity, return.data = TRUE)
#Fidelity is listed using the str command
str(GOL_atts)

#######
#CART Decision tree
library("rpart")

cart.model <- rpart(ADE_PRESENT ~ ., data = train.set, method="class") 
cart.pred <- predict(cart.model, newdata = test.set, type = "class") 
table(Predictions = cart.pred, Actual = test.set$ADE_PRESENT)

#CART Confusion Matrix for Disagreement Calculation 
mean(cart.pred == test.set$ADE_PRESENT)

#######
#C50 Decision Tree 
library("C50")
c50.model <- C5.0(ADE_PRESENT ~ ., data = train.set, method="class") 
c50.pred <- predict(c50.model, newdata = test.set, type = "class") 
table(Predictions = c50.pred, Actual = test.set$ADE_PRESENT)

#C5.0 Confusion Matrix for Disagreement Calculation
mean(c50.pred == test.set$ADE_PRESENT)

#######
#GLM MODEL 
library("gam")
glm.model <- glm(ADE_PRESENT ~ ., data = train.set, family = binomial())
    
summary(glm.model) # display results
confint(glm.model) # 95% CI for the coefficients
predict(glm.model, type="terms") # predicted values
############################################################################
#LIME
library(lime)

# Split up the data set
lime_test <- MIMIC3_DAMI2_NOMISS[1:5, 1:4]
lime_train <- MIMIC3_DAMI2_NOMISS[-(1:5), 1:4]
lime_lab <- MIMIC3_DAMI2_NOMISS[[5]][-(1:5)]

# Create Random Forest model on data
lime_model <- train(lime_train, lime_lab, method = 'rf')

# Create an explainer object
explainer <- lime(lime_train, lime_model)

# Explain new observation
explanation <- explain(lime_test, explainer, n_labels = 1, n_features = 2)

# The output is provided in a consistent tabular format and includes the
# output from the model.
head(explanation)
summary(explanation)

# feature plot shows variables by importance 
plot_features(explanation)
plot_text_explanations(explanation)