{{/* vim: set filetype=mustache: */}}
{{/*
Expand the name of the chart.
*/}}
{{- define "chart.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "chart.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default .Chart.Name .Values.nameOverride -}}
{{- if contains $name .Release.Name -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "chart.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Common labels
*/}}
{{- define "chart.labels" -}}
helm.sh/chart: {{ include "chart.chart" . }}
{{ include "chart.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end -}}

{{/*
Selector labels
*/}}
{{- define "chart.selectorLabels" -}}
app.kubernetes.io/name: {{ include "chart.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{/*
Create the name of the service account to use
*/}}
{{- define "chart.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}
    {{ default (include "chart.fullname" .) .Values.serviceAccount.name }}
{{- else -}}
    {{ default "default" .Values.serviceAccount.name }}
{{- end -}}
{{- end -}}

{{- define "k8gb.extdnsProvider" -}}
{{- if .Values.rfc2136.enabled }}
{{- print "rfc2136" -}}
{{- end -}}
{{- if .Values.azuredns.enabled }}
{{- print "azure-dns" -}}
{{- end -}}
{{- end -}}

{{- define "k8gb.extdnsOwnerID" -}}
k8gb-{{ index (split ":" (index (split ";" (include "k8gb.dnsZonesString" .)) "_0")) "_1" }}-{{ .Values.k8gb.clusterGeoTag }}
{{- end -}}

{{- define "k8gb.edgeDNSServers" -}}
{{- if .Values.k8gb.edgeDNSServer -}}
{{ .Values.k8gb.edgeDNSServer }}
{{- else -}}
{{ join "," .Values.k8gb.edgeDNSServers }}
{{- end -}}
{{- end -}}

{{- define "k8gb.dnsZonesString" -}}
{{- $entries := list -}}
{{- range .Values.k8gb.dnsZones }}
  {{- $dnsZoneNegTTL := toString (.dnsZoneNegTTL | default "300") }}
  {{- $entry := printf "%s:%s:%s" .parentZone .loadBalancedZone $dnsZoneNegTTL }}
  {{- $entries = append $entries $entry }}
{{- end }}
{{- join ";" $entries }}
{{- end }}

{{- define "k8gb.extdnsProviderOpts" -}}
{{- if .Values.azuredns.enabled -}}
        - --azure-resource-group={{ .Values.azuredns.resourceGroup }}
{{- end }}
{{- if and (eq .Values.rfc2136.enabled true) (eq .Values.rfc2136.rfc2136auth.insecure.enabled true) -}}
        - --rfc2136-insecure
{{- end -}}
{{- if and (eq .Values.rfc2136.enabled true) (eq .Values.rfc2136.rfc2136auth.tsig.enabled true) -}}
        - --rfc2136-tsig-axfr
{{- range $k, $v := .Values.rfc2136.rfc2136auth.tsig.tsigCreds -}}
{{- range $kk, $vv := $v }}
        - --rfc2136-{{ $kk }}={{ $vv }}
{{- end }}
{{- end }}
{{- end -}}
{{- if and (eq .Values.rfc2136.enabled true) (eq .Values.rfc2136.rfc2136auth.gssTsig.enabled true) -}}
        - --rfc2136-gss-tsig
{{- range $k, $v := .Values.rfc2136.rfc2136auth.gssTsig.gssTsigCreds -}}
{{- range $kk, $vv := $v }}
        - --rfc2136-{{ $kk }}={{ $vv }}
{{- end }}
{{- end }}
{{- end -}}
{{ if .Values.rfc2136.enabled -}}
{{- range $k, $v := .Values.rfc2136.rfc2136Opts -}}
{{- range $kk, $vv := $v }}
        - --rfc2136-{{ $kk }}={{ $vv }}
{{- end }}
{{- end }}
{{- $dnsZonesRaw := include "k8gb.dnsZonesString" . }}
{{- $dnsZones := split ";" $dnsZonesRaw }}
{{- range $dnsZones }}
    {{- $parts := split ":" . }}
    {{- $zone := index $parts "_0" }}
        - --rfc2136-zone={{ $zone }}
{{- end }}
        env:
        - name: EXTERNAL_DNS_RFC2136_TSIG_SECRET
          valueFrom:
            secretKeyRef:
              name: rfc2136
              key: secret
{{- end -}}
{{- end -}}
{{- define "k8gb.metrics_port" -}}
{{ print (split ":" .Values.k8gb.metricsAddress)._1 }}
{{- end -}}

{{- define "external-dns.azure-credentials" -}}
{{- if and (eq .Values.azuredns.enabled true) (eq .Values.azuredns.createAuthSecret.enabled true) -}}
{
  "tenantId": "{{ .Values.azuredns.createAuthSecret.tenantId }}",
  "subscriptionId": "{{ .Values.azuredns.createAuthSecret.subscriptionId }}",
  "resourceGroup": "{{ .Values.azuredns.createAuthSecret.resourceGroup }}",
  {{- if .Values.azuredns.createAuthSecret.aadClientId }}
  "aadClientId": "{{ .Values.azuredns.createAuthSecret.aadClientId }}",
  {{- end }}
  {{- if .Values.azuredns.createAuthSecret.aadClientSecret }}
  "aadClientSecret": "{{ .Values.azuredns.createAuthSecret.aadClientSecret }}",
  {{- end }}
  "useManagedIdentityExtension": {{ .Values.azuredns.createAuthSecret.useManagedIdentityExtension | default false }},
  {{- if .Values.azuredns.createAuthSecret.userAssignedIdentityID }}
  "userAssignedIdentityID": "{{ .Values.azuredns.createAuthSecret.userAssignedIdentityID }}",
  {{- end }}
  "useWorkloadIdentityExtension": {{ .Values.azuredns.createAuthSecret.useWorkloadIdentityExtension | default false }}
}
{{- end -}}
{{- end -}}
