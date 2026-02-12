# DSC 3.0

## Installation

````powershell
winget install --id 9NVTPZWRC6KQ --source msstore --accept-package-agreements
````

## Usage

Create `example.dsc.config.yaml` config file:

````yaml
$schema: https://aka.ms/dsc/schemas/v3/bundled/config/document.json
resources:
- name: Set registry key (with DSC 3.0)
  type: Microsoft.Windows/Registry
  properties:
    keyPath: HKCU\dsc\example\key
    _exist:  true
- name: Set PSDSC resources (with PSDSC) 
  type: Microsoft.Windows/WindowsPowerShell
  properties:
    resources:
    - name: Set env var (with PSDSC)
      type: PSDesiredStateConfiguration/Environment
      properties:
        Name: DSC_EXAMPLE
        Ensure: Present
        Value: Set by DSC
````

Apply it:

````powershell
dsc config set --file ./example.dsc.config.yaml
````

## Notes post-tests

Pas convaincu par la solution pour les raisons suivantes:

* Couche supplémentaire pour la configuration des machines
* Nécessite l'installation de composants supplémentaires (winget, dsc, vcredist, ...)
* Obliger de s'appuyer sur PSDSC pour créer des env var par exemple (faire du neuf avec du vieux ...)
* Usage de YAML pour la déclaration ...

Je vais donc repartir sur mon approche hybride dans le dossier `post-deploy`. On a le côté déclaratif via les fichiers json et toute le logique est gérée par PS.