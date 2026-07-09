// Jenkinsfile — Terraform pipeline for aws-devops-kafka-infra-v2
// Location of Terraform root module in this repo:
def TF_DIR = 'terraform'

pipeline {
    agent any

    options {
        timestamps()
        disableConcurrentBuilds()
        buildDiscarder(logRotator(numToKeepStr: '20'))
        ansiColor('xterm')
    }

    parameters {
        choice(
            name: 'ACTION',
            choices: ['plan', 'apply', 'destroy'],
            description: 'Terraform action to run'
        )
        string(
            name: 'TF_VAR_project_name',
            defaultValue: 'deepali',
            description: 'Project name prefix for resources (overrides terraform/variables.tf default)'
        )
        string(
            name: 'TF_VAR_environment',
            defaultValue: 'production',
            description: 'Environment name (overrides terraform/variables.tf default)'
        )
        string(
            name: 'AWS_REGION',
            defaultValue: 'ap-south-1',
            description: 'AWS region to deploy into'
        )
        booleanParam(
            name: 'AUTO_APPROVE',
            defaultValue: false,
            description: 'Skip the manual approval gate for apply/destroy (use with caution)'
        )
        booleanParam(
            name: 'RUN_ANSIBLE',
            defaultValue: true,
            description: 'After a successful apply, run the Ansible playbook against the freshly generated inventory'
        )
    }

    environment {
        // Jenkins credential IDs — create these under Manage Jenkins > Credentials first
        AWS_ACCESS_KEY_ID     = credentials('aws-access-key-id')
        AWS_SECRET_ACCESS_KEY = credentials('aws-secret-access-key')
        AWS_DEFAULT_REGION    = "${params.AWS_REGION}"
        TF_IN_AUTOMATION      = 'true'
        TF_INPUT              = 'false'
        ANSIBLE_HOST_KEY_CHECKING = 'False'
        ANSIBLE_DIR           = 'ansible'
    }

    stages {

        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Terraform Version') {
            steps {
                dir(TF_DIR) {
                    sh 'terraform -version'
                }
            }
        }

        stage('Terraform Init') {
            steps {
                dir(TF_DIR) {
                    sh 'terraform init -input=false'
                }
            }
        }

        stage('Terraform Validate') {
            steps {
                dir(TF_DIR) {
                    sh 'terraform validate'
                }
            }
        }

        stage('Terraform Plan') {
            steps {
                dir(TF_DIR) {
                    sh """
                        terraform plan -input=false \
                            -var="project_name=${params.TF_VAR_project_name}" \
                            -var="environment=${params.TF_VAR_environment}" \
                            -var="aws_region=${params.AWS_REGION}" \
                            -out=tfplan
                    """
                }
            }
        }

        stage('Approval') {
            when {
                expression { params.ACTION in ['apply', 'destroy'] && !params.AUTO_APPROVE }
            }
            steps {
                script {
                    def approver = input(
                        message: "Confirm Terraform ${params.ACTION.toUpperCase()} for project '${params.TF_VAR_project_name}' (${params.TF_VAR_environment}) in ${params.AWS_REGION}?",
                        ok: 'Proceed',
                        submitterParameter: 'APPROVER'
                    )
                    echo "Approved by: ${approver}"
                }
            }
        }

        stage('Terraform Apply') {
            when {
                expression { params.ACTION == 'apply' }
            }
            steps {
                dir(TF_DIR) {
                    sh 'terraform apply -input=false -auto-approve tfplan'
                }
            }
        }

        stage('Terraform Destroy') {
            when {
                expression { params.ACTION == 'destroy' }
            }
            steps {
                dir(TF_DIR) {
                    sh """
                        terraform destroy -input=false -auto-approve \
                            -var="project_name=${params.TF_VAR_project_name}" \
                            -var="environment=${params.TF_VAR_environment}" \
                            -var="aws_region=${params.AWS_REGION}"
                    """
                }
            }
        }

        stage('Terraform Output') {
            when {
                expression { params.ACTION == 'apply' }
            }
            steps {
                dir(TF_DIR) {
                    sh 'terraform output'
                }
            }
        }

        // ---------------------------------------------------------------
        // From here on: Ansible stages. These only run after a successful
        // 'apply', because that's when terraform/modules/ec2/main.tf
        // regenerates ansible/inventory/hosts.yml with the fresh EC2 IPs.
        // ---------------------------------------------------------------

        stage('Export EC2 IPs as Env Vars') {
            when {
                expression { params.ACTION == 'apply' && params.RUN_ANSIBLE }
            }
            steps {
                dir(TF_DIR) {
                    script {
                        // terraform output -json gives every output defined in
                        // terraform/outputs.tf; jq pulls out the .value of each
                        // and we stash it on env.* so any later stage (Ansible,
                        // notifications, etc.) can read it as a plain env var.
                        env.BASTION_IP    = sh(script: "terraform output -raw bastion_public_ip", returnStdout: true).trim()
                        env.KAFKA_IPS     = sh(script: "terraform output -json kafka_broker_private_ips | jq -r 'join(\",\")'", returnStdout: true).trim()
                        env.INVENTORY_PATH = sh(script: "terraform output -raw ansible_inventory_path", returnStdout: true).trim()
                    }
                    echo "BASTION_IP=${env.BASTION_IP}"
                    echo "KAFKA_IPS=${env.KAFKA_IPS}"
                    echo "INVENTORY_PATH=${env.INVENTORY_PATH}"
                }
            }
        }

        stage('Wait for SSH') {
            when {
                expression { params.ACTION == 'apply' && params.RUN_ANSIBLE }
            }
            steps {
                sshagent(credentials: ['kafka-ssh-key']) {
                    sh """
                        echo "Waiting for SSH on bastion (${env.BASTION_IP})..."
                        timeout 180 bash -c "until ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 ubuntu@${env.BASTION_IP} true 2>/dev/null; do sleep 5; done"

                        for ip in \$(echo ${env.KAFKA_IPS} | tr ',' ' '); do
                            echo "Waiting for SSH on kafka broker \$ip (via bastion)..."
                            timeout 180 bash -c "until ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 -o ProxyCommand='ssh -o StrictHostKeyChecking=no -W %h:%p ubuntu@${env.BASTION_IP}' ubuntu@\$ip true 2>/dev/null; do sleep 5; done"
                        done
                    """
                }
            }
        }

        stage('Ansible Ping') {
            when {
                expression { params.ACTION == 'apply' && params.RUN_ANSIBLE }
            }
            steps {
                dir(ANSIBLE_DIR) {
                    sshagent(credentials: ['kafka-ssh-key']) {
                        sh 'ansible -i inventory/hosts.yml all -m ping'
                    }
                }
            }
        }

        stage('Ansible Playbook') {
            when {
                expression { params.ACTION == 'apply' && params.RUN_ANSIBLE }
            }
            steps {
                dir(ANSIBLE_DIR) {
                    sshagent(credentials: ['kafka-ssh-key']) {
                        sh """
                            ansible-playbook -i inventory/hosts.yml playbooks/site.yml \
                                --extra-vars "bastion_ip=${env.BASTION_IP}"
                        """
                    }
                }
            }
        }
    }

    post {
        always {
            dir(TF_DIR) {
                archiveArtifacts artifacts: 'tfplan', allowEmptyArchive: true, fingerprint: true
            }
        }
        success {
            echo "Terraform ${params.ACTION} completed successfully."
        }
        failure {
            echo "Terraform ${params.ACTION} failed. Check the logs above."
        }
    }
}
