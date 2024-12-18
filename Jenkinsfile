pipeline {
    agent any
    tools {
        maven 'maven_latest'
        'org.jenkinsci.plugins.docker.commons.tools.DockerTool' 'docker_latest'
    }
    stages {
        stage('StaticCodeAnalysis') {
            when {
                changeRequest()
            }
            steps {
                echo 'Static code analysis'
            }
        }

        stage('UnitTests') {
            when {
                changeRequest()
            }
            steps {
                echo 'Unit tests'
            }
        }

        stage('PackageBuild') {
            when {
                changeRequest()
            }
            steps {
                echo 'Package build'
            }
        }

        stage('ReleaseGitTag') {
            when {
                branch 'main'
            }
            steps {
                echo 'Tagging release in SCM'
            }
        }

        stage('ArtifactBuild') {
            when {
                anyOf {
                    changeRequest()
                    branch 'main'
                }
            }
            steps {
                echo 'Building docker image'
            }
        }

        stage('ArtifactUpload') {
            when {
                anyOf {
                    changeRequest()
                    branch 'main'
                }
            }
            steps {
                echo 'Uploading docker image to Google Artifact Registry'
            }
        }

        stage('ArtifactDeploy') {
            when {
                branch 'main'
            }
            steps {
                echo 'Deploying docker image to Google Kubernetes Engine cluster'
            }
        }
    }
}
