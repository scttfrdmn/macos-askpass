// Jenkins Pipeline Example: macOS Integration Testing with ASKPASS
// Place this content in a Jenkinsfile or use as a Pipeline script

pipeline {
    agent {
        label 'macos'  // Use macOS build agent
    }
    
    environment {
        // Set CI password from Jenkins credentials
        CI_SUDO_PASSWORD = credentials('macos-sudo-password')
        
        // ASKPASS program location (will be set after installation)
        SUDO_ASKPASS = '/usr/local/bin/askpass'
        
        // Optional: Enable debug logging
        // ASKPASS_DEBUG = '1'
    }
    
    options {
        // Set build timeout
        timeout(time: 30, unit: 'MINUTES')
        
        // Keep build logs
        buildDiscarder(logRotator(numToKeepStr: '10'))
        
        // Skip default checkout
        skipDefaultCheckout()
    }
    
    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }
        
        stage('Install ASKPASS') {
            steps {
                script {
                    // Check if askpass is already installed
                    def askpassExists = sh(
                        script: 'command -v askpass >/dev/null 2>&1',
                        returnStatus: true
                    ) == 0
                    
                    if (!askpassExists) {
                        echo '📦 Installing macOS ASKPASS...'
                        sh '''
                            curl -fsSL https://raw.githubusercontent.com/scttfrdmn/macos-askpass/main/install.sh | bash
                        '''
                    } else {
                        echo '✅ ASKPASS already installed'
                    }
                    
                    // Verify installation and show version
                    sh 'askpass version'
                }
            }
        }
        
        stage('Setup Environment') {
            steps {
                echo '🔧 Setting up ASKPASS environment...'
                
                script {
                    // Test ASKPASS functionality
                    try {
                        sh 'askpass test'
                        echo '✅ ASKPASS test successful'
                    } catch (Exception e) {
                        error "❌ ASKPASS test failed: ${e.getMessage()}"
                    }
                }
            }
        }
        
        stage('Unit Tests') {
            steps {
                echo '🧪 Running unit tests...'
                sh '''
                    # Run tests that don't require root privileges
                    make test-unit || exit 1
                '''
            }
        }
        
        stage('Integration Tests') {
            when {
                anyOf {
                    branch 'main'
                    branch 'develop'
                    // Or run when PR has specific label
                    changeRequest target: 'main'
                }
            }
            
            steps {
                echo '🔧 Running integration tests with ASKPASS...'
                
                script {
                    try {
                        sh '''
                            # Run integration tests requiring sudo
                            sudo -A make integration-test
                            
                            # Example sudo commands that now work:
                            # sudo -A systemsetup -getremotelogin
                            # sudo -A ./network-config-test.sh
                            # sudo -A launchctl load test-daemon.plist
                        '''
                        echo '✅ Integration tests completed successfully'
                    } catch (Exception e) {
                        error "❌ Integration tests failed: ${e.getMessage()}"
                    }
                }
            }
            
            post {
                always {
                    echo '🧹 Cleaning up after integration tests...'
                    sh '''
                        # Cleanup commands (don't fail the build if cleanup fails)
                        sudo -A ./cleanup-integration-test.sh || true
                        sudo -A pkill -f test_daemon || true
                        sudo -A launchctl unload test-daemon.plist || true
                    '''
                }
            }
        }
        
        stage('Security Scan') {
            when {
                anyOf {
                    branch 'main'
                    changeRequest()
                }
            }
            
            steps {
                echo '🔒 Running security scans...'
                
                script {
                    // Install security tools if needed
                    sh '''
                        if ! command -v shellcheck >/dev/null 2>&1; then
                            echo "Installing shellcheck..."
                            brew install shellcheck
                        fi
                    '''
                    
                    // Run security scans
                    sh '''
                        # Scan shell scripts
                        find . -name "*.sh" -exec shellcheck {} \\; || true
                        
                        # Custom security checks
                        make security-scan || true
                    '''
                }
            }
        }
        
        stage('Build Package') {
            when {
                anyOf {
                    branch 'main'
                    tag pattern: 'v\\d+\\.\\d+\\.\\d+', comparator: 'REGEXP'
                }
            }
            
            steps {
                echo '📦 Building release package...'
                sh '''
                    make build
                '''
            }
            
            post {
                success {
                    // Archive build artifacts
                    archiveArtifacts artifacts: 'dist/*.tar.gz', fingerprint: true
                }
            }
        }
    }
    
    post {
        always {
            echo '📊 Build completed'
            
            // Clean workspace
            cleanWs()
        }
        
        success {
            echo '✅ Pipeline completed successfully'
            
            // Optional: Send notification
            // slackSend(
            //     channel: '#ci-cd',
            //     color: 'good',
            //     message: ":white_check_mark: macOS build successful: ${env.JOB_NAME} - ${env.BUILD_NUMBER}"
            // )
        }
        
        failure {
            echo '❌ Pipeline failed'
            
            // Optional: Send failure notification
            // slackSend(
            //     channel: '#ci-cd',
            //     color: 'danger',
            //     message: ":x: macOS build failed: ${env.JOB_NAME} - ${env.BUILD_NUMBER}"
            // )
        }
        
        unstable {
            echo '⚠️ Pipeline unstable'
        }
    }
}

/*
Setup Instructions for Jenkins:

1. Jenkins Credentials:
   - Go to Jenkins > Manage Jenkins > Manage Credentials
   - Add new "Secret text" credential:
     - ID: 'macos-sudo-password'
     - Secret: Your macOS user's sudo password
     - Description: 'macOS sudo password for ASKPASS'

2. macOS Build Agent:
   - Ensure you have a macOS agent configured
   - Agent should have:
     - Xcode Command Line Tools installed
     - Homebrew installed (for additional tools)
     - Network connectivity to install ASKPASS

3. Pipeline Configuration:
   - Create new Pipeline job
   - Configure SCM to point to your repository
   - Use this Jenkinsfile
   - Set appropriate branch patterns for builds

4. Security Considerations:
   - Limit credential access to specific jobs/folders
   - Use dedicated test user account for CI
   - Regularly rotate the sudo password
   - Monitor build logs for credential exposure

5. Optional Integrations:
   - Slack notifications for build status
   - Email notifications for failures
   - Integration with ticketing systems
   - Artifact publishing to repository

6. Testing the Pipeline:
   - Start with unit tests only
   - Gradually enable integration tests
   - Verify cleanup procedures work correctly
   - Test failure scenarios and recovery

Example Multibranch Pipeline Configuration:
- Branch Sources: Git
- Build Configuration: by Jenkinsfile
- Branch Discovery: All branches, Pull requests from origin
- Property Strategy: All branches get the same properties
*/