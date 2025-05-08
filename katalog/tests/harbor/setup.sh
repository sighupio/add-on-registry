#!/usr/bin/env bats
# shellcheck disable=SC2154,SC2034,SC2086,SC2103
# Copyright (c) 2017-present SIGHUP s.r.l All rights reserved.
# Use of this source code is governed by a BSD-style
# license that can be found in the LICENSE file.

load "./../lib/helper"

@test "[SETUP] pre-requirements - CRDs" {
    info
    crds(){
        kubectl apply -f https://raw.githubusercontent.com/sighupio/fury-kubernetes-monitoring/v1.12.0/katalog/prometheus-operator/crd-prometheus.yml
        kubectl apply -f https://raw.githubusercontent.com/sighupio/fury-kubernetes-monitoring/v1.12.0/katalog/prometheus-operator/crd-servicemonitor.yml
        kubectl apply -f https://raw.githubusercontent.com/sighupio/fury-kubernetes-monitoring/v1.12.0/katalog/prometheus-operator/crd-rule.yml
    }
    run crds
    [ "$status" -eq 0 ]
}

@test "[SETUP] requirements - ingress" {
    info
    install_ingress(){
        cd katalog/tests/harbor/config
        furyctl legacy vendor -H
        cd -
        kustomize build katalog/tests/harbor/config | kubectl apply -f -
    }
    loop_it install_ingress 20 3
    status=${loop_it_result}
    [ "$status" -eq 0 ]
}

@test "[SETUP] requirements - Check Ingress" {
    info
    test(){
        status=$(kubectl get pods -n ingress-nginx -l app=ingress-nginx -o jsonpath="{.items[*].status.phase}")
        if [ "${status}" != "Running" ]; then return 1; fi
    }
    loop_it test 30 2
    status=${loop_it_result}
    [ "$status" -eq 0 ]
}

@test "[SETUP] requirements - Check cert-manager" {
    info
    test(){
        status=$(kubectl get pods -n cert-manager -o jsonpath='{range .items[*]}{.status.phase}{"\n"}{end}' | uniq)
        if [ "${status}" != "Running" ]; then return 1; fi
    }
    loop_it test 30 2
    status=${loop_it_result}
    [ "$status" -eq 0 ]
}

@test "[SETUP] requirements - Prepare Harbor manifests" {
    info
    files_to_change="""
    examples/full-harbor/kustomization.yaml
    examples/full-harbor/patch/ingress.yml
    """
    for file in ${files_to_change}
    do
        sed -i'' -e 's/%YOUR_DOMAIN%/'"${TEST_DOMAIN}"'/g; s/%YOUR_PORT%/'"${HTTPS_PORT}"'/g' "${file}"

    done
}

@test "[SETUP] Harbor" {
    info
    install_harbor(){
        kustomize build examples/full-harbor | kubectl apply -f -
    }
    loop_it install_harbor 20 3
    status=${loop_it_result}
    [ "$status" -eq 0 ]
}

@test "[SETUP] Check Harbor" {
    info
    test(){
        status=$(kubectl get pods -n registry -l app=harbor -o jsonpath='{range .items[*].status.containerStatuses[*]}{.ready}{"\n"}{end}' | uniq)
        kubectl get pods -n registry -l app=harbor -o jsonpath='{range .items[*].status.containerStatuses[*]}{.ready}{"\n"}{end}' | uniq >&3
        kubectl get pods -n registry -l app=harbor >&3
        kubectl describe pods -n registry -l app=harbor | grep -i events >&3
        if [ "${status}" != "true" ]; then return 1; fi
    }
    loop_it test 30 30
    status=${loop_it_result}
    [ "$status" -eq 0 ]
}

@test "[SETUP] Check Harbor connectivity" {
   info
   test(){
       curl -k -v https://harbor."${TEST_DOMAIN}":"${HTTPS_PORT}"/api/v2.0/health >&3
       kubectl get ingress -n registry >&3
       kubectl describe ingress -n registry >&3
   }
   loop_it test 30 5
   status=${loop_it_result}
   [ "$status" -eq 0 ]
}
