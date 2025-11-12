pipeline {
    agent none
    
    options {
        // Prevent concurrent runs to avoid conflicts
        disableConcurrentBuilds()
    }
    
    stages {
        stage('Clear Workspaces') {
            steps {
                script {
                    // Get list of node names (serializable)
                    def nodeNames = getNodeNames()
                    
                    echo "Found ${nodeNames.size()} node(s) to process: ${nodeNames}"
                    
                    // Process each node
                    for (String nodeName in nodeNames) {
                        echo "Processing node: ${nodeName}"
                        
                        // Wait for node to be idle
                        waitForNodeIdle(nodeName)
                        
                        // Clean workspace on the node
                        cleanWorkspaceOnNode(nodeName)
                    }
                    
                    echo "Workspace cleanup completed on all nodes"
                }
            }
        }
    }
}

// Get list of all node names (returns serializable list)
@NonCPS
def getNodeNames() {
    def jenkins = Jenkins.instance
    def names = []
    
    // Add built-in node (use empty string for built-in node label)
    names.add('')  // Empty string represents the built-in/controller node
    
    // Add all agent nodes that are online
    jenkins.nodes.each { node ->
        def computer = node.toComputer()
        if (computer != null && !computer.isOffline()) {
            names.add(node.getNodeName())
        }
    }
    
    return names
}

// Check if a node is busy
@NonCPS
def isNodeBusy(String nodeName) {
    def jenkins = Jenkins.instance
    def node = null
    
    if (nodeName == '' || nodeName == null) {
        // Built-in/controller node
        node = jenkins
    } else {
        node = jenkins.getNode(nodeName)
    }
    
    if (node == null) {
        return false
    }
    
    def computer = node.toComputer()
    
    if (computer == null || computer.isOffline()) {
        return false
    }
    
    def executors = computer.getExecutors()
    
    for (executor in executors) {
        if (executor.isBusy()) {
            return true
        }
    }
    
    return false
}

// Function to wait for a node to become idle
def waitForNodeIdle(String nodeName) {
    def maxWaitTime = 3600 // Maximum wait time in seconds (1 hour)
    def checkInterval = 30 // Check every 30 seconds
    def elapsed = 0
    
    while (elapsed < maxWaitTime) {
        def busy = isNodeBusy(nodeName)
        
        if (!busy) {
            echo "Node ${nodeName} is idle and ready for cleanup"
            return
        }
        
        echo "Node ${nodeName} is busy. Waiting ${checkInterval} seconds... (${elapsed}/${maxWaitTime}s elapsed)"
        sleep(checkInterval)
        elapsed += checkInterval
    }
    
    echo "Warning: Timeout waiting for node ${nodeName} to become idle after ${maxWaitTime} seconds"
}

// Function to clean workspace on a specific node
def cleanWorkspaceOnNode(String nodeName) {
    try {
        if (nodeName == '' || nodeName == null) {
            // For built-in/controller node - use empty string as label
            node('') {
                echo "Cleaning workspace on built-in node"
                deleteDir()
                echo "Workspace cleaned on built-in node"
            }
        } else {
            // For agent nodes
            node(nodeName) {
                echo "Cleaning workspace on node: ${nodeName}"
                deleteDir()
                echo "Workspace cleaned on node: ${nodeName}"
            }
        }
    } catch (Exception e) {
        echo "Error cleaning workspace on node ${nodeName}: ${e.message}"
    }
}
