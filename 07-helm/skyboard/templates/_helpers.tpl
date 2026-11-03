{{/* Nom complet : la release si elle contient déjà « skyboard », sinon <release>-skyboard (63 car. max).
     Avec une release nommée « skyboard », le Service API s'appelle « skyboard-api » : c'est le nom que le front attend. */}}
{{- define "skyboard.fullname" -}}
{{- if contains .Chart.Name .Release.Name -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name .Chart.Name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}

{{/* Labels communs recommandés */}}
{{- define "skyboard.labels" -}}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version }}
app.kubernetes.io/part-of: skyboard
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Values.image.api.tag | default .Chart.AppVersion | quote }}
{{- end -}}

{{/* Tag d'image API : valeur ou appVersion */}}
{{- define "skyboard.apiTag" -}}
{{- .Values.image.api.tag | default .Chart.AppVersion -}}
{{- end -}}
