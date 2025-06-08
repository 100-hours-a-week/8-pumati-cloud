{{/*
프론트엔드 애플리케이션 Helm 헬퍼 템플릿
*/}}

{{/*
차트 이름 확장
*/}}
{{- define "pumati-frontend.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
전체 이름 생성 (릴리스 이름 + 차트 이름)
*/}}
{{- define "pumati-frontend.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
차트 레이블 생성
*/}}
{{- define "pumati-frontend.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
공통 레이블
*/}}
{{- define "pumati-frontend.labels" -}}
helm.sh/chart: {{ include "pumati-frontend.chart" . }}
{{ include "pumati-frontend.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
셀렉터 레이블
*/}}
{{- define "pumati-frontend.selectorLabels" -}}
app.kubernetes.io/name: {{ include "pumati-frontend.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
서비스 계정 이름 생성
*/}}
{{- define "pumati-frontend.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "pumati-frontend.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }} 