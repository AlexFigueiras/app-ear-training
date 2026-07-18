# Módulo 04 — Validação de ambiente (fail-fast)

## Depende de: 03

## Objetivo
Garantir que a aplicação **falhe ao subir** se qualquer variável de ambiente obrigatória faltar ou for inválida — nada de `process.env.X` espalhado e silencioso.

## Entregáveis obrigatórios

### 1. `shared/config/env.ts` (ou equivalente da stack)
- Schema estrito (Zod em TS; Pydantic Settings em Python; envalid como alternativa) validando **todas** as variáveis no boot.
- Variáveis obrigatórias → falha imediata com mensagem clara indicando QUAL variável faltou/é inválida.
- Variáveis opcionais → declaradas como opcionais **explicitamente** no schema, nunca por omissão.
- Exporta um objeto tipado e congelado (`env`) — o resto do código importa daqui, **nunca** lê `process.env` diretamente (exceção: o próprio `env.ts` e configs de build que rodam antes do runtime).
- Separar variáveis server-only de variáveis públicas de cliente (ex.: prefixo `NEXT_PUBLIC_` no Next.js). Uma variável server-only referenciada em código cliente é vazamento — o módulo 06 vai escanear isso.

Exemplo mínimo (adapte as variáveis reais aos parâmetros do projeto):
```ts
import { z } from 'zod';

const schema = z.object({
  NODE_ENV: z.enum(['development', 'test', 'production']),
  DATABASE_URL: z.string().url(),
  // server-only — jamais importar em código cliente:
  SERVICE_ROLE_KEY: z.string().min(1).optional(),
});

const parsed = schema.safeParse(process.env);
if (!parsed.success) {
  console.error('❌ Variáveis de ambiente inválidas:', parsed.error.flatten().fieldErrors);
  throw new Error('Configuração de ambiente inválida — abortando boot.');
}
export const env = Object.freeze(parsed.data);
```

### 2. `.env.example` sincronizado
Toda chave do schema aparece no `.env.example` (sem valores reais). A partir de agora, adicionar variável = atualizar schema **e** example no mesmo commit.

### 3. Wiring no boot
Importar `env.ts` no ponto de entrada mais cedo possível da app (ex.: `instrumentation.ts`/entrypoint do servidor), para que o processo morra no boot, não no primeiro uso.

### 4. Teste unitário
`shared/config/__tests__/env.test.ts`: com env válido parseia; com variável obrigatória ausente, lança erro.

## Regras invioláveis deste módulo
- Nenhuma variável lida fora do `env.ts`.
- Falha de validação = processo não sobe (fail-fast), nunca warning.

## Critério de aceite
- [ ] Teste unitário passa (`npm run test`).
- [ ] **Teste negativo:** rodar a app (ou um script que importa `env.ts`) sem uma variável obrigatória → processo aborta com mensagem apontando a variável. Restaurar depois.
- [ ] `.env.example` contém todas as chaves do schema.

## Ao concluir
1. Marcar ✅ na linha 04 do `MASTER-PLAN.md`.
2. Entrada no `DECISIONS.md` (lib de validação escolhida e por quê).
3. PARAR. Não iniciar o módulo 05 nesta mesma resposta.

## Cláusula anti-simplificação
Nenhum item dos Entregáveis é opcional. Antes de encerrar, liste cada entregável e seu status. Se algo ficou de fora, o módulo NÃO está concluído.
