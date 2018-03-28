# Functional Evaluation of Five Methods Interpreting a Random Forest Classifying Adverse Events
Research Topics in Data Sceince 

Machine learning model interpretability is a significant unmet need. Current research has not properly addressed how or what to interpret in black box models. The desiderata of interpretability research, in critical areas such as medicine, include: trust, causality, transferability and informativeness. The interpretability framework is a trade-off between quantitative and qualitative metrics. A random forest classifying adverse-drug events requires an interpreter to functionally replicate 	predictions given a set of inputs

# Objective 
Identify a functionally performant interpreter through evaluations against a developed random forest. Methods Five approaches were evaluated using goodness measure fidelity. Comparisons were made against a developed random forest.

# Results 
No method was conclusively identified due to a misrepresentative goodness measure that does not exhaustively assess functional interpretability. This highlights the urgent need for robust model-agnostic evaluation methods. Fidelity is not appropriate for comparing interpreters. 

# Investigated Interpreters 
 
 a)	Golden Eye takes a given classifier function with input feature vectors to create groups of interacting attributes which significantly affect predictive performance. A fidelity threshold is applied to find ideal groupings. Note that their formal definition differs from the one used in this research, estimating predictive agreement between randomized and original datasets. Considered more complex than most other interpreters investigated since the interaction of variables is assessed as a means to predict classification. 
 
b)	Local Interpretable Model-Agnostic Explanations (LIME) assess predictions by applying a linear model to a given instance and its neighbouring points to approximate the classifier. These local explanations, the linear model in other words, must behave in significant agreement with the nearby feature space of any given function (agnostic). Hence a trade-off between complexity and local fidelity. They suggest global understanding by selecting a few diverse instances that are meant to represent the model behavior in its entirety. Linear interpreters have low logic complexity. 

c)	Generalized Linear Models (GLM) provide global understanding by estimating a linear model with a non-linear function as part of the predictor. It is a form of linear regression.  In other words, non-linear models are represented using bases (Fourier equation for instance) and covariates, allowing for accurate prediction of datasets that do not have normal distribution. In the original research model parameters were identified through a reweighted iterative approach of least squares. Since, similar more complex models have been developed, in healthcare settings under the umbrella term generalized additive model. It has relatively low logic complexity but less so than LIME that can explain it on a case by case basis. 

d)	Classification and Regression Trees (CART) are widely recognized as interpretable and a commonly used form of decision trees. Most relevant attributes are identified by computing Gini index, and are located in the top levels of the tree. Descending in significance until root nodes are obtained for classification. It supports numerical target variables due to its regression.

e)	C5.0 is an extended vesion of the C4.5 decision tree, available as an R-package. It computes rule sets using information gain but does not operate by regression like CART. Ross Quinlan's original work on the ID3 led to this updated version, well-accepted in the data science community today. Both types of decision trees have staight-forward logic and low complexity. 
