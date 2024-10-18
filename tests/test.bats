#!/usr/bin/env bats

# See the openbao-plugin-auth-jwt README for prereqs and setup.

# OpenBao logs will be written to BAO_OUTFILE.
# BATs test logs will be written to SETUP_TEARDOWN_OUTFILE.

export BAO_ADDR='http://127.0.0.1:8200'
SETUP_TEARDOWN_OUTFILE=/tmp/bats-test.log
BAO_OUTFILE=/tmp/openbao-jwt.log
BAO_TOKEN='root'
BAO_STARTUP_TIMEOUT=15

# error if these are not set
[ ${CLIENT_ID:?} ]
[ ${CLIENT_SECRET:?} ]
[ ${ISSUER:?} ]

# assert_status evaluates if `status` is equal to $1. If they are not equal a
# log is written to the output file. This makes use of the BATs `status` and
# `output` globals.
#
# Parameters:
#   expect
# Globals:
#   status
#   output
assert_status() {
  local expect
  expect="$1"

  [ "${status}" -eq "${expect}" ] || \
    log_err "bad status: expect: ${expect}, got: ${status} \noutput:\n${output}"
}

log() {
  echo "INFO: $(date): [$BATS_TEST_NAME]: $@" >> $SETUP_TEARDOWN_OUTFILE
}

log_err() {
  echo -e "ERROR: $(date): [$BATS_TEST_NAME]: $@" >> $SETUP_TEARDOWN_OUTFILE
  exit 1
}

# setup_file runs once before all tests
setup_file(){
    # clear log file
    echo "" > $SETUP_TEARDOWN_OUTFILE

    BAO_TOKEN='root'

    log "BEGIN SETUP"

    if [[ -n ${BAO_IMAGE} ]]; then
      log "docker using BAO_IMAGE: $BAO_IMAGE"
      docker pull ${BAO_IMAGE?}

      docker run \
        --name=bao \
        --hostname=bao \
        -p 8200:8200 \
        -e BAO_DEV_ROOT_TOKEN_ID="root" \
        -e BAO_ADDR="http://localhost:8200" \
        -e BAO_DEV_LISTEN_ADDRESS="0.0.0.0:8200" \
        --privileged \
        --detach ${BAO_IMAGE?}
    else
      log "using local bao binary"
      ./bao server -dev -dev-root-token-id=root \
        -log-level=trace > $BAO_OUTFILE 2>&1 &
    fi

    log "waiting for bao..."
    i=0
    while ! bao status >/dev/null 2>&1; do
      sleep 1
      ((i=i+1))
      [ $i -gt $BAO_STARTUP_TIMEOUT ] && log_err "timed out waiting for bao to start"
    done

    bao login ${BAO_TOKEN?}

    run bao status
    assert_status 0
    log "bao started successfully"

    log "END SETUP"
}

# teardown_file runs once after all tests complete
teardown_file(){
    log "BEGIN TEARDOWN"

    if [[ -n ${BAO_IMAGE} ]]; then
      log "removing bao docker container"
      docker rm bao --force
    else
      log "killing bao process"
      pkill bao
    fi

    log "END TEARDOWN"
}

@test "Enable oidc auth" {
    run bao auth enable oidc
    assert_status 0
}

@test "Setup kv and policies" {
    run bao secrets enable -version=2 kv
    assert_status 0

    run bao kv put kv/my-secret/secret-1 value=1234
    assert_status 0

    run bao kv put kv/your-secret/secret-2 value=5678
    assert_status 0

    run bao policy write test-policy -<<EOF
path "kv/data/my-secret/*" {
  capabilities = [ "read" ]
}

EOF
    assert_status 0

}

@test "POST /auth/oidc/config - write config" {
    run bao write auth/oidc/config \
      oidc_discovery_url="$ISSUER" \
      oidc_client_id="$CLIENT_ID" \
      oidc_client_secret="$CLIENT_SECRET" \
      default_role="test-role" \
      bound_issuer="localhost"
    assert_status 0
}

@test "POST /auth/oidc/role/:name - create a role" {
    run bao write auth/oidc/role/test-role \
      user_claim="sub" \
      allowed_redirect_uris="http://localhost:8250/oidc/callback,http://localhost:8200/ui/vault/auth/oidc/oidc/callback" \
      bound_audiences="$CLIENT_ID" \
      oidc_scopes="openid" \
      ttl=1h \
      policies="test-policy" \
      verbose_oidc_logging=true
    assert_status 0

    run bao write auth/oidc/role/test-role-2 \
      user_claim="sub" \
      allowed_redirect_uris="http://localhost:8250/oidc/callback,http://localhost:8200/ui/vault/auth/oidc/oidc/callback" \
      bound_audiences="$CLIENT_ID" \
      oidc_scopes="openid" \
      ttl=1h \
      policies="test-policy" \
      verbose_oidc_logging=true
    assert_status 0
}

@test "LIST /auth/oidc/role - list roles" {
    run bao list auth/oidc/role
    assert_status 0
}

@test "GET /auth/oidc/role/:name - read a role" {
    run bao read auth/oidc/role/test-role
    assert_status 0
}

@test "DELETE /auth/oidc/role/:name - delete a role" {
    run bao delete auth/oidc/role/test-role-2
    assert_status 0
}

# this test will open your default browser and ask you to login with your
# OIDC Provider
@test "Login with oidc auth" {
    unset BAO_TOKEN
    run bao login -method=oidc
    assert_status 0
}

@test "Test policy prevents kv read" {
    unset BAO_TOKEN
    run bao kv get kv/your-secret/secret-2
    assert_status 2
}

@test "Test policy allows kv read" {
    unset BAO_TOKEN
    run bao kv get kv/my-secret/secret-1
    assert_status 0
}
