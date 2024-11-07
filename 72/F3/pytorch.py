import torch
import torch.nn as nn
import torch.optim as optim
import torch.nn.init as init
# Define the model (your previously defined FNN with 3 layers, batch normalization, ReLU, etc.)
class FNN(nn.Module):
    def __init__(self):
        super(FNN, self).__init__()
        self.layer1 = nn.Sequential(
            nn.Linear(784, 256),
            nn.BatchNorm1d(256),
            nn.ReLU(),
            nn.Dropout(0.2)
        )
        self.layer2 = nn.Sequential(
            nn.Linear(256, 128),
            nn.BatchNorm1d(128),
            nn.ReLU(),
            nn.Dropout(0.2)
        )
        self.layer3 = nn.Sequential(
            nn.Linear(128, 10),
            nn.Softmax(dim=1)
        )

        # Apply Xavier initialization
        init.xavier_uniform_(self.layer1[0].weight)
        init.xavier_uniform_(self.layer2[0].weight)
        init.xavier_uniform_(self.layer3[0].weight)
        
        # Apply bias initialization (optional but can improve training)
        init.zeros_(self.layer1[0].bias)
        init.zeros_(self.layer2[0].bias)
        init.zeros_(self.layer3[0].bias)

    def forward(self, x):
        x = x.view(-1, 784)  # Flatten the images
        x = self.layer1(x)
        x = self.layer2(x)
        x = self.layer3(x)
        return x

# Initialize model, loss function, and optimizer
model = FNN()
# Hyperparameters
num_epochs = 10
learning_rate = 0.001

# Define loss function and optimizer
criterion = nn.CrossEntropyLoss()
optimizer = optim.Adam(model.parameters(), lr=learning_rate)

# Training loop
for epoch in range(num_epochs):
    model.train()  # Set the model to training mode
    running_loss = 0.0
    
    for images, labels in train_loader:
        # Zero the parameter gradients
        optimizer.zero_grad()
        
        # Forward pass
        outputs = model.forward(images)
        loss = criterion(outputs, labels)
        
        # Backward pass and optimization
        loss.backward()
        optimizer.step()
        
        # Accumulate running loss
        running_loss += loss.item()
    
    # Print average loss for the epoch
    average_loss = running_loss / len(train_loader)
    print(f"Epoch [{epoch + 1}/{num_epochs}], Loss: {average_loss:.4f}")

# Evaluate on test set
model.eval()  # Switch to evaluation mode
correct = 0
total = 0
test_loss = 0.0

with torch.no_grad():  # Disable gradient computation
    for images, labels in test_loader:
        outputs = model.forward(images)
        loss = criterion(outputs, labels)
        test_loss += loss.item()
        
        # Get predictions
        _, predicted = torch.max(outputs, 1)
        total += labels.size(0)
        correct += (predicted == labels).sum().item()

# Calculate and print the test accuracy and loss
average_test_loss = test_loss / len(test_loader)
test_accuracy = correct / total
print(f"Test Loss: {average_test_loss:.4f}")
print(f"Test Accuracy: {test_accuracy:.4f}")