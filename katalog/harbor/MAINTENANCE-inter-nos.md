The follwing items are noteworthy behaviours or configurations that have been found in the registry add-on before starting the update to the newest upstream version. 
This file is supposed to only be used in the feature branch and should be deleted or not merged anyway in the main branch. 

1. In the MAINTENANCE.md file, there's a reference to the "promcat.io" website as a source for the PrometheusRules used in the add-on, but the website is no longer reachable. It is very likely that the rules it contained where the ones present in this repo https://github.com/sysdiglabs/promcat-resources/tree/master, which has been unmantained for 2+ years. 
We are evaluating the re-write from scratch of a few simple PrometheusRules, that we might want to add with a PR to the upstream project that we use for other systems' rules,  https://github.com/samber/awesome-prometheus-alerts

2. In the core component used in the add-on, currently a self-signed PKI is bootstrapped using cert-manager CRDs, but it is not clear what this PKI is uses for. 
The generated secret seems to be used as a volume in the same spot where upstream configures an Ingress-related TLS certificate, but that is unlikely to work in the add-on configuration.
We might want to test wether this PKI is actually used, possibly by testing that the whole deployment keeps working even if the PKI-related secrets get deleted. 

