+++
title = "3. Regression Analysis & MSE Loss function"
type = "learning-notes"
tags = [
  "deep-learning",
  "machine-learning",
  "neural-networks",
  "regression",
  "mse",
  "loss-function",
  "cost-function",
  "learning-notes"
]
weight = 3
+++

In regression analysis, a deep learning neural network can produce more accurate predictions (or estimates) when it is trained on appropriate input data, its architecture is well-suited to the problem, and the training process is properly carried out.

In deep learning, quantitative metrics are needed to evaluate the accuracy of the model's predictions.

When evaluating regression predictions, the Mean Squared Error (MSE) is commonly used as the loss function.

The Mean Squared Error is defined as:

$$
MSE = \frac{1}{N}\sum_{i=1}^{N}(y_i - \hat{y}_i)^2
$$

where $y_i$ is the true value, $\hat{y}_i$ is the predicted value, and $N$ is the number of samples.

Squaring the errors ensures that positive and negative differences do not cancel out, and it penalizes larger errors more heavily. This makes MSE a simple yet effective way to evaluate regression models.

- If $\hat{y}_i$ is exactly the same as $y_i$, the MSE will be $0$.
- If the predictions are close but not identical to the true values, the MSE will be a small positive number. Larger discrepancies will result in a higher MSE.

In deep learning a **loss function** measures how well the model's prediction matches the true value for a single data point.
When the losses across all samples are averaged, this is often called the **cost function**.

The goal of training a neural network is to minimize this function.
For regression tasks, the **Mean Squared Error (MSE)** is one of the most widely used cost functions because it provides a clear, differentiable measure of error that works well with gradient descent optimization.
