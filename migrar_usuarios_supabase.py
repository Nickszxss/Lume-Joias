#!/usr/bin/env python3
"""
=====================================================================
SGE — Script Administrativo de Migração de Usuários para Supabase Auth
Projeto: Lume-Joias / LumeEstoque
=====================================================================
Este script lê os usuários da tabela public.usuarios e realiza
a simulação (--dry-run) ou a migração via Supabase Admin API
preservando os hashes BCrypt ($2a$10$).

USO SEGURO (Somente Ambiente Local / CI Segura):
  export SUPABASE_URL="https://pssrggtqmphcpqbdhjex.supabase.co"
  export SUPABASE_SERVICE_ROLE_KEY="sua_chave_service_role_aqui"

  python3 migrar_usuarios_supabase.py --dry-run
=====================================================================
"""

import sys
import os
import argparse
import json
import urllib.request
import urllib.error

# Configurações padrão do projeto
DEFAULT_SUPABASE_URL = "https://pssrggtqmphcpqbdhjex.supabase.co"
DEFAULT_ANON_KEY = "sb_publishable_p9yLQDR5lj0uT0F5NQ1_aw_6TyS9job"


def mascarar_hash(hash_str):
  if not hash_str:
    return "N/A"
  if len(hash_str) >= 15:
    return hash_str[:7] + "..." + hash_str[-4:]
  return "***"


def buscar_usuarios_publicos(supabase_url, anon_key):
  url = f"{supabase_url}/rest/v1/usuarios?select=id,nome,email,senha,cargo,tipo,filial_id,ativo"
  headers = {
    "apikey": anon_key,
    "Authorization": f"Bearer {anon_key}",
    "Content-Type": "application/json"
  }
  req = urllib.request.Request(url, headers=headers)
  try:
    with urllib.request.urlopen(req) as response:
      return json.loads(response.read().decode('utf-8'))
  except Exception as e:
    print(f"[ERRO] Falha ao consultar public.usuarios: {e}")
    return []


def buscar_usuarios_auth(supabase_url, service_role_key):
  if not service_role_key:
    return []
  url = f"{supabase_url}/auth/v1/admin/users"
  headers = {
    "apikey": service_role_key,
    "Authorization": f"Bearer {service_role_key}",
    "Content-Type": "application/json"
  }
  req = urllib.request.Request(url, headers=headers)
  try:
    with urllib.request.urlopen(req) as response:
      res_json = json.loads(response.read().decode('utf-8'))
      return res_json.get("users", [])
  except Exception as e:
    print(f"[AVISO] Não foi possível listar auth.users via Admin API (chave service_role não configurada ou inválida): {e}")
    return []


def validar_usuario(usr):
  erros = []
  email = usr.get("email")
  senha_hash = usr.get("senha")

  if not email or "@" not in email:
    erros.append("E-mail ausente ou inválido")

  if not senha_hash:
    erros.append("Hash de senha ausente")
  elif len(senha_hash) != 60 or not senha_hash.startswith("$2a$"):
    erros.append(f"Hash fora do padrão BCrypt $2a$ (tamanho: {len(senha_hash)})")

  return erros


def executar_migracao(dry_run=True):
  supabase_url = os.environ.get("SUPABASE_URL", DEFAULT_SUPABASE_URL)
  anon_key = os.environ.get("SUPABASE_ANON_KEY", DEFAULT_ANON_KEY)
  service_role_key = os.environ.get("SUPABASE_SERVICE_ROLE_KEY", "")

  print("=====================================================================")
  print("SGE — SCRIPT ADMINISTRATIVO DE MIGRAÇÃO DE USUÁRIOS (SUPABASE AUTH)")
  print("=====================================================================")
  print(f"Modo de Execução : {'[DRY-RUN / SIMULAÇÃO]' if dry_run else '[MIGRAÇÃO REAL]'}")
  print(f"URL do Supabase  : {supabase_url}")
  print(f"Service Role Key : {'Configurada (Oculta)' if service_role_key else 'Não fornecida (Simulação local)'}")
  print("---------------------------------------------------------------------")

  usuarios = buscar_usuarios_publicos(supabase_url, anon_key)
  print(f"Total de registros encontrados em public.usuarios: {len(usuarios)}\n")

  auth_users = buscar_usuarios_auth(supabase_url, service_role_key) if service_role_key else []
  auth_emails = {u.get("email", "").lower(): u for u in auth_users}

  prontos = 0
  existentes_auth = 0
  com_erros = 0

  for idx, usr in enumerate(usuarios, 1):
    email = usr.get("email", "").strip().lower()
    nome = usr.get("nome", "")
    cargo = usr.get("cargo") or usr.get("tipo", "funcionario")
    filial_id = usr.get("filial_id")
    hash_senha = usr.get("senha", "")

    erros = validar_usuario(usr)

    print(f"[{idx}/{len(usuarios)}] Usuário: {email or 'SEM EMAIL'}")
    print(f"      Nome      : {nome}")
    print(f"      Cargo     : {cargo} | Filial ID: {filial_id if filial_id is not None else 'Global (Gerente)'}")
    print(f"      Hash      : {mascarar_hash(hash_senha)}")

    if erros:
      com_erros += 1
      print(f"      Status    : [ERRO DE VALIDAÇÃO] -> {', '.join(erros)}")
    elif email in auth_emails:
      existentes_auth += 1
      print(f"      Status    : [IGNORADO] -> Usuário já existe em auth.users")
    else:
      prontos += 1
      print(f"      Status    : [{'PRONTO PARA MIGRAÇÃO' if dry_run else 'MIGRANDO...'}]")

      if not dry_run and service_role_key:
        payload = {
          "email": email,
          "password_hash": hash_senha,
          "email_confirm": True,
          "user_metadata": {
            "nome": nome,
            "cargo": cargo,
            "filial_id": filial_id
          }
        }
        # Apenas se executado fora de dry-run com service_role
        url_create = f"{supabase_url}/auth/v1/admin/users"
        headers_create = {
          "apikey": service_role_key,
          "Authorization": f"Bearer {service_role_key}",
          "Content-Type": "application/json"
        }
        try:
          req = urllib.request.Request(url_create, data=json.dumps(payload).encode('utf-8'), headers=headers_create, method='POST')
          with urllib.request.urlopen(req) as resp:
            res_data = json.loads(resp.read().decode('utf-8'))
            print(f"      Resultado : [SUCESSO] -> Criado UUID {res_data.get('id')}")
        except urllib.error.HTTPError as he:
          err_body = he.read().decode('utf-8')
          print(f"      Resultado : [FALHA NA API] -> {he.code}: {err_body}")
        except Exception as ex:
          print(f"      Resultado : [FALHA DE REDE] -> {ex}")

    print("-" * 65)

  print("\n=====================================================================")
  print("RESUMO DO PROCESSAMENTO")
  print("=====================================================================")
  print(f"Total de Usuários Processados  : {len(usuarios)}")
  print(f"Prontos para Migração          : {prontos}")
  print(f"Já Existentes no Auth          : {existentes_auth}")
  print(f"Com Erros de Validação         : {com_erros}")
  if dry_run:
    print("\n[MENSAGEM] NENHUMA ALTERAÇÃO FOI REALIZADA NO SUPABASE (MODO DRY-RUN).")
  print("=====================================================================")


if __name__ == "__main__":
  parser = argparse.ArgumentParser(description="Script de migração de usuários de public.usuarios para Supabase Auth.")
  parser.add_argument("--dry-run", action="store_true", default=True, help="Executa apenas simulação sem escrita no Supabase (padrão).")
  parser.add_argument("--execute", action="store_true", help="Executa a migração real de escrita (exige SUPABASE_SERVICE_ROLE_KEY).")
  args = parser.parse_args()

  is_dry = not args.execute
  executar_migracao(dry_run=is_dry)
