// ExecuteHub reference Jenkins pipeline.
//
// This declarative pipeline is what the app's own CI entry point runs:
//
//   1. Checkout  — pull the repository (SCM step; requires a proper SCM source
//                  on the job, or run it with checkout overridden in tests).
//   2. Install   — install the app's dependencies.
//   3. Build     — compile/build the app (illustrative; swap for your build).
//   4. Trigger ExecuteHub — POST /api/v1/ci/jenkins/test_runs with the project's
//                  CI token. ExecuteHub creates the Pipeline + Build + TestRun
//                  idempotently (retried builds never duplicate anything) and
//                  schedules the test run.
//   5. Wait for release gate — poll GET /api/v1/pipelines/<id>/status with the
//                  same CI token until the DeploymentGate is decided.
//   6. Gate check — pass only when the gate is approved; fail on blocked/expired.
//   7. Deploy     — STUB ONLY. ExecuteHub release gates never deploy for real;
//                  approve/reject only mutate gate + pipeline state. Wire this
//                  stage up to your real deploy target when ready.
//
// Configure the job with an SCM pointing at this repository and supply:
//   EXECUTEHUB_URL        (default http://host.docker.internal:3001)
//   EXECUTEHUB_PROJECT_ID (the ExecuteHub project id owning the CI token)
//   EXECUTEHUB_CI_TOKEN   (secret text; prefer a Jenkins secret credential bound
//                          to this parameter in production — see JENKINS_SETUP.md)
pipeline {
  agent any

  options {
    timestamps()
    disableConcurrentBuilds()
    timeout(time: 30, unit: 'MINUTES')
  }

  environment {
    // Git refs from the Jenkins environment. Fall back to "main" for freestyle
    // jobs that have no multibranch refs.
    REVISION_BRANCH = "${env.BRANCH_NAME ?: env.GIT_BRANCH ?: 'main'}"
    REVISION_SHA    = "${env.GIT_COMMIT}"
  }

  parameters {
    string(name: 'EXECUTEHUB_URL', defaultValue: 'http://host.docker.internal:3001',
           description: 'ExecuteHub API base URL (host.docker.internal when ExecuteHub runs on the host, or the compose service name otherwise)')
    string(name: 'EXECUTEHUB_PROJECT_ID', defaultValue: '',
           description: 'ExecuteHub project id that owns the CI token')
    string(name: 'EXECUTEHUB_CI_TOKEN', defaultValue: '',
           description: 'ExecuteHub project CI token (secret text). In production bind this to a Jenkins secret credential.')
    string(name: 'PROJECT_DIR', defaultValue: 'frontend',
           description: 'Sub-directory of the repo where the build runs')
    string(name: 'TOTAL_TESTS', defaultValue: '40',
           description: 'Test count sent to ExecuteHub (0 lets ExecuteHub use the suite/config default)')
  }

  stages {
    stage('Checkout') {
      steps {
        checkout scm
      }
    }

    stage('Install') {
      steps {
        dir("${params.PROJECT_DIR}") {
          sh 'npm ci'
        }
      }
    }

    stage('Build') {
      steps {
        dir("${params.PROJECT_DIR}") {
          sh 'npm run build'
        }
      }
    }

    stage('Trigger ExecuteHub') {
      steps {
        script {
          if (!params.EXECUTEHUB_URL) { error 'EXECUTEHUB_URL is required' }
          if (!params.EXECUTEHUB_PROJECT_ID) { error 'EXECUTEHUB_PROJECT_ID is required' }
          if (!params.EXECUTEHUB_CI_TOKEN) { error 'EXECUTEHUB_CI_TOKEN is required' }

          def total = params.TOTAL_TESTS.toInteger()
          def payload = """{
            "project_id": ${params.EXECUTEHUB_PROJECT_ID},
            "branch": "${REVISION_BRANCH}",
            "commit_sha": "${REVISION_SHA}",
            "jenkins_build_number": ${env.BUILD_NUMBER},
            "job_name": "${env.JOB_NAME}",
            "total_tests": ${total}
          }"""

          def resp = sh(script: """
            curl -sS -X POST "${params.EXECUTEHUB_URL}/api/v1/ci/jenkins/test_runs" \
              -H "Authorization: Bearer ${params.EXECUTEHUB_CI_TOKEN}" \
              -H "Content-Type: application/json" \
              --data-binary '${payload}'
          """, returnStdout: true).trim()

          def body = readJSON(text: resp)
          if (body.pipeline?.id == null) {
            error "ExecuteHub trigger failed: ${body.error ?: resp}"
          }
          env.PIPELINE_ID = body.pipeline.id.toString()
          echo "Triggered ExecuteHub pipeline #${env.PIPELINE_ID} for ${env.JOB_NAME} #${env.BUILD_NUMBER}"
        }
      }
    }

    stage('Wait for release gate') {
      steps {
        script {
          def decided = false
          def gateStatus = 'pending'
          def pipelineStatus = 'running'

          // 60 x 10s = up to 10 minutes. The ExecuteHub test run + gate
          // evaluation normally settles far sooner.
          for (int i = 0; i < 60; i++) {
            sleep time: 10, unit: 'SECONDS'

            def statusResp = sh(script: """
              curl -sS "${params.EXECUTEHUB_URL}/api/v1/pipelines/${env.PIPELINE_ID}/status" \
                -H "Authorization: Bearer ${params.EXECUTEHUB_CI_TOKEN}"
            """, returnStdout: true).trim()

            def body = readJSON(text: statusResp)
            pipelineStatus = body.pipeline?.status ?: 'running'
            gateStatus = body.deployment_gate?.status ?: 'pending'

            if (gateStatus != 'pending') { decided = true; break }
            if (pipelineStatus in ['passed', 'failed', 'blocked']) { decided = true; break }
          }

          if (!decided) { error 'Timed out waiting for ExecuteHub release gate decision' }
          env.DEPLOY_GATE_STATUS = gateStatus
          echo "Release gate decided: ${gateStatus} (pipeline ${pipelineStatus})"
        }
      }
    }

    stage('Gate check') {
      steps {
        script {
          if (env.DEPLOY_GATE_STATUS != 'approved' && env.DEPLOY_GATE_STATUS != 'passed') {
            error "Release gate blocked (status: ${env.DEPLOY_GATE_STATUS}). Approve it in ExecuteHub and rerun."
          }
          echo 'Release gate passed — safe to deploy'
        }
      }
    }

    stage('Deploy') {
      steps {
        script {
          // STUB ONLY. ExecuteHub release gates never perform real deployments;
          // approve/reject simply settle gate + pipeline state on the ExecuteHub
          // side. Replace the body of this stage with your real deploy step.
          echo "DEPLOY STUB: ${env.JOB_NAME} #${env.BUILD_NUMBER} would promote ${env.REVISION_SHA} to <environment>"
        }
      }
    }
  }

  post {
    always {
      echo "Pipeline ${env.JOB_NAME} #${env.BUILD_NUMBER} finished: ${currentBuild.currentResult}"
    }
    failure {
      // Rerun is safe: a re-run retriggers ExecuteHub with the SAME build
      // number (jenkins:<job>:<build>) so it resumes the existing pipeline.
      echo 'Build failed. Rerun is idempotent on the ExecuteHub side.'
    }
  }
}
