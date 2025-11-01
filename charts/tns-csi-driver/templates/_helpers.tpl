{{/*
Expand the name of the chart.
*/}}
{{- define "tns-csi-driver.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
If release name contains "tns-csi", just use the release name to avoid duplication.
*/}}
{{- define "tns-csi-driver.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- if contains "tns-csi" .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-tns-csi" .Release.Name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "tns-csi-driver.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "tns-csi-driver.labels" -}}
helm.sh/chart: {{ include "tns-csi-driver.chart" . }}
{{ include "tns-csi-driver.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- with .Values.customLabels }}
{{ toYaml . }}
{{- end }}
{{- end }}

{{/*
Selector labels for controller
*/}}
{{- define "tns-csi-driver.controller.selectorLabels" -}}
app.kubernetes.io/name: {{ include "tns-csi-driver.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/component: controller
{{- end }}

{{/*
Selector labels for node
*/}}
{{- define "tns-csi-driver.node.selectorLabels" -}}
app.kubernetes.io/name: {{ include "tns-csi-driver.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/component: node
{{- end }}

{{/*
Selector labels
*/}}
{{- define "tns-csi-driver.selectorLabels" -}}
app.kubernetes.io/name: {{ include "tns-csi-driver.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the controller service account to use
*/}}
{{- define "tns-csi-driver.controller.serviceAccountName" -}}
{{- printf "%s-controller" (include "tns-csi-driver.fullname" .) }}
{{- end }}

{{/*
Create the name of the node service account to use
*/}}
{{- define "tns-csi-driver.node.serviceAccountName" -}}
{{- printf "%s-node" (include "tns-csi-driver.fullname" .) }}
{{- end }}

{{/*
Create the name of the secret
*/}}
{{- define "tns-csi-driver.secretName" -}}
{{- if .Values.truenas.existingSecret }}
{{- .Values.truenas.existingSecret }}
{{- else }}
{{- printf "%s-secret" (include "tns-csi-driver.fullname" .) }}
{{- end }}
{{- end }}

{{/*
Return the appropriate apiVersion for RBAC APIs
*/}}
{{- define "tns-csi-driver.rbac.apiVersion" -}}
{{- if .Capabilities.APIVersions.Has "rbac.authorization.k8s.io/v1" -}}
rbac.authorization.k8s.io/v1
{{- else -}}
rbac.authorization.k8s.io/v1beta1
{{- end -}}
{{- end -}}

{{/*
Return the appropriate apiVersion for CSIDriver
*/}}
{{- define "tns-csi-driver.csidriver.apiVersion" -}}
{{- if .Capabilities.APIVersions.Has "storage.k8s.io/v1" -}}
storage.k8s.io/v1
{{- else -}}
storage.k8s.io/v1beta1
{{- end -}}
{{- end -}}

{{/*
Create the CSI driver name
*/}}
{{- define "tns-csi-driver.driverName" -}}
{{- .Values.driverName | default "tns.csi.io" }}
{{- end }}
