# Spring AI — Qwen partagé sur AWS (Terraform)

Déployer une EC2 **g6.2xlarge** GPU (Paris), **Ollama + Qwen3 14B**, **LiteLLM + PostgreSQL**, **Caddy/HTTPS** et **4 clés virtuelles**; tout détruire à la fin. À usage de **TP temporaire**, pas une plateforme multi-tenant de production.

## Prérequis

- Compte AWS avec droits EC2, EIP, IAM, SSM, Secrets Manager, Route53 (seulement si zone fournie), et quota `Running On-Demand G and VT instances` suffisant. Région `eu-west-3` et instance G6 disponible dans le subnet choisi.
- VPC **default** et subnet **public** existants, avec route Internet Gateway et Internet sortant (image, Docker, modèle, ACME).
- AWS CLI v2 configuré sur Windows (`aws sts get-caller-identity`), Terraform >=1.5, PowerShell.
- Nom de domaine **réel et contrôlé**. Choisir DNS Route53 géré par Terraform ou créer manuellement l'enregistrement A. Port 80 et 443 ouverts depuis Internet pour certificat Caddy.
- **Droits SecretsManager:GetSecretValue** pour l'identité du formateur qui récupère les clés.
- Vérifier le chemin SSM de la GPU AMI dans la région; le projet utilise Ubuntu 22.04 GPU NVIDIA via SSM public. L'AMI peut évoluer : mettre à jour si dépréciée.

## 1. Configurer

```powershell
Copy-Item .\terraform\terraform.tfvars.example .\terraform\terraform.tfvars
notepad .\terraform\terraform.tfvars
```

Mettre `domain = "llm.votre-domaine.fr"`. Si DNS dans Route53, renseigner `route53_zone_id` de la zone **publique**.

⚠️ Sans Route53 : après le lancement, récupérer `public_ip` et créer **A llm.votre-domaine.fr → IP** chez votre DNS. La première demande de certificat par Caddy peut échouer temporairement tant que le DNS n'est pas propagé. Caddy retente automatiquement.

## 2. Créer

```powershell
.\scripts\deploy.ps1
```

Attendre que le téléchargement du modèle et la configuration de LiteLLM soient terminés, ce qui peut prendre plusieurs minutes. `terraform apply` ne bloque pas jusqu'à ce que le modèle soit prêt.

## 3. Vérifier et récupérer les clés

```powershell
.\scripts\check.ps1
.\scripts\get-keys.ps1
.\scripts\test-api.ps1 -ApiUrl 'https://llm.votre-domaine.fr' -ApiKey 'sk-...'
```

Les quatre clés `stagiaire1`, `stagiaire2`, `stagiaire3`, `formateur` sont générées **sur EC2** par LiteLLM et sauvegardées **dans AWS Secrets Manager**. **Elles ne sont pas dans le state Terraform.** Le secret maître est réservé au formateur. Stockage temporaire chmod 600 sur le disque racine chiffré ; suppression du fichier de clés après upload Secrets Manager. Ne pas partager le contenu intégral du secret.

Si les clés ne sont pas encore présentes, attendre que l'installation soit finie, puis inspecter les logs sur EC2 via Session Manager (`sudo tail -100 /var/log/spring-ai-bootstrap.log`; ne pas publier de logs contenant des secrets).

**Test de sécurité :** sans Bearer, `GET /v1/models` doit renvoyer `401` ou `403`. La commande `check.ps1` le vérifie.

## 4. Spring AI — application.yml

Ajouter le starter `spring-ai-starter-model-openai` (pas celui d'Ollama pour cet endpoint LiteLLM):

```yaml
spring:
  ai:
    model:
      chat: openai
    openai:
      base-url: https://llm.votre-domaine.fr
      api-key: ${LLM_API_KEY}
      chat:
        options:
          model: qwen-training
```


Les stagiaires définissent chacun leur variable `LLM_API_KEY` dans la session de leur IDE/application. Ne pas committer de clé.

## 5. Supprimer TOUTES les ressources suivies

```powershell
.\scripts\destroy.ps1
```

Cette commande supprime EC2, volume root, EIP, Security Group, rôle IAM, profil, secret et entrée Route53 **si gérée**. Le DNS externe manuel doit être retiré manuellement. **Secrets Manager est configuré pour suppression sans délai de récupération.** Ne pas supprimer le dossier ou fichier `.tfstate` avant le destroy. Conserver un état Terraform unique; pas de déploiements concurrents. Après destruction, contrôler AWS Console pour confirmer qu'aucune ressource hors Terraform ne reste.

## Sécurité et limites

- Ports entrants **80/443 uniquement**. Aucun SSH, Ollama:11434, LiteLLM:4000 ni PostgreSQL:5432 publiquement exposé. Caddy reverse proxy vers LiteLLM. Les quatre clés sont limitées au modèle `qwen-training` et à **15 requêtes/minute par clé**.
- **Le DNS est indispensable** pour TLS public. Pas d'URL HTTPS certifiée sans domaine; ne pas désactiver la vérification TLS.
- **L'URL administrative LiteLLM est aussi accessible sur le domaine**, mais protégée par sa clé maître. Pour un durcissement supplémentaire, restreindre `/ui`, `/key/*`, `/team/*`, `/user/*` via Caddy ou mettre ces endpoints derrière VPN.
- Quatre requêtes de contexte important sur L4 24 Go peuvent saturer la VRAM. Commencer avec Qwen3 14B, contexte 4096, `OLLAMA_NUM_PARALLEL=2` (file d'attente). `qwen3:30b` non garanti simultanément sur cette carte.
- Le tag `ghcr.io/berriai/litellm:main-stable` bouge. **Pour la stabilité du cours, remplacer par un tag digest testé** quelques jours avant la formation.
- `curl | sh` pour installer Ollama est pratique pour un TP, mais en environnement durable figer et vérifier les binaires et signatures.
- Les noms, contenus des prompts et réponses peuvent figurer dans les journaux des composants. Ne pas utiliser de données confidentielles dans un atelier public.
- État Terraform local = pas de verrouillage partagé. Pour travail en équipe/CI, utiliser un backend S3 avec versioning et locking et des credentials IAM dédiés.
- **Aucun job de destruction programmé n'est activé par défaut.** Le script manuel détruit réellement. Pour une suppression programmée fiable, lancer `destroy.ps1` via un runner disposant de l'état Terraform et des credentials ; mieux : backend distant + GitHub Actions OIDC avec validation, à ajouter selon ton environnement.
- Coût On-Demand et coût Secrets Manager, EIP, stockage continuent d'être facturés tant que conservés. Vérifier prix et quotas régionaux avant le déploiement.

## Diagnostic

- SSM permet un accès sans SSH : console AWS > Systems Manager > Session Manager > instance, sous réserve de SSM agent et réseau sortant.
- `sudo journalctl -u ollama -n 100`
- `cd /opt/spring-ai && sudo docker-compose logs --tail=100 litellm caddy db`
- `sudo tail -100 /var/log/spring-ai-bootstrap.log`
- Vérifier le DNS : `nslookup llm.votre-domaine.fr` doit retourner l'EIP Terraform.
- Vérifier que Docker et NVIDIA fonctionnent sur l'AMI.
