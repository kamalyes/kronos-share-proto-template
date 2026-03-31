name: Release Contract

run-name: 📦 [release] ${{ inputs.version || inputs.bump || github.ref_name }} by @${{ github.actor }}

# ============================================================================
# 协议中心发版 | Contract-hub release
#
# 这条流水线把「一堆 proto」变成「一个可被引用的版本」，下游三类消费者都靠它：
#   1. Go 服务    → go get <module>@vX.Y.Z   取 pb/ 里的结构体与 gRPC stub
#   2. TS SDK     → 取 release 资产 openapi.swagger.yaml 重新生成并发 npm
#   3. 其它语言    → 同一份 openapi.swagger.yaml 喂给各自的生成器
#
# 为什么要有版本号而不是让下游跟 commit hash：
#   - hash 读不出兼容性，v1.3.0 → v2.0.0 一眼就知道要改代码
#   - Go module 的 MVS 选版本只认 tag，跟 hash 的 pseudo-version 在多服务共享
#     同一协议时会出现「同一个 proto 两个版本」的诡异冲突
#   - npm 的 SDK 必须有语义化版本才能发布，而它的版本应当跟协议版本对得上
#
# 两个入口，殊途同归 | Two entry points, one path:
#   workflow_dispatch  手动发版：按 bump 算出下一个版本号，校验通过后打 tag 并发布
#   push tags: v*      本地或别处打好 tag 推上来，同样走校验与发布
#
# 为什么不拆成「打 tag 的 job」+「发布的 job」：用 GITHUB_TOKEN 推送的 tag
# 不会触发任何工作流（GitHub 为防递归的硬性限制），拆开就必须额外配一个 PAT
# 合成一个 job 后，核心发版流程零额外凭证要求
#
# [EN] This pipeline turns "a pile of protos" into "one referenceable version", which all
# three kinds of downstream consumers depend on:
#   1. Go services  -> go get <module>@vX.Y.Z for the structs and gRPC stubs under pb/
#   2. TS SDK       -> pull the openapi.swagger.yaml release asset, regenerate, publish to npm
#   3. Other langs  -> feed the same openapi.swagger.yaml to their own generators
#
# Why versions instead of letting downstream track commit hashes: a hash says nothing about
# compatibility, while v1.3.0 -> v2.0.0 does; Go's minimal version selection only understands
# tags, and pseudo-versions produce bizarre "same proto, two versions" conflicts once several
# services share one contract; and an npm SDK needs a semantic version to publish at all,
# which should line up with the contract version.
#
# The two triggers converge on one job because a tag pushed with GITHUB_TOKEN never triggers
# another workflow (GitHub's anti-recursion rule), so splitting tagging from publishing would
# force every user to configure a PAT. One job keeps the core flow credential-free.
# ============================================================================

permissions:
  contents: write # 创建 tag 与 Release | create the tag and the Release

on:
  push:
    tags:
      - 'v*'
  workflow_dispatch:
    inputs:
      bump:
        description: '版本递增方式（给定 version 时忽略）| How to bump (ignored when version is given)'
        required: false
        type: choice
        options:
          - patch
          - minor
          - major
        default: patch
      version:
        description: '显式版本号，如 v1.4.0（留空则按 bump 自动计算）| Explicit version such as v1.4.0'
        required: false
        type: string
        default: ''
      dry-run:
        description: '只校验并打印将要发布的内容，不打 tag 不发布 | Verify and print only'
        required: false
        type: boolean
        default: false

# 发版不允许并行：两个 run 同时打 tag 会产生竞态
# [EN] Releases never run in parallel: concurrent runs would race on the tag
concurrency:
  group: release-contract
  cancel-in-progress: false

jobs:
  release:
    name: Verify & Publish
    runs-on: ubuntu-latest
    timeout-minutes: 25

    # 放在 job 级而不是 step 级：step 自己的 env 在它自己的 if 里不保证可见，
    # 而这两个值恰恰是用来写 if 条件的
    # [EN] Job level rather than step level: a step's own env is not reliably visible in its
    # own `if`, and these two exist precisely to be used in `if` conditions
    env:
      DRY_RUN: ${{ inputs.dry-run }}
      OPS_CLI_APP_ID: ${{ secrets.OPS_CLI_APP_ID }}

    steps:
      - name: ⬇️ Checkout Repository
        uses: actions/checkout@v6
        with:
          # 发布说明要对比上一个 tag，必须有完整历史与全部 tag
          # [EN] The notes diff against the previous tag, so full history and all tags are required
          fetch-depth: 0

      - name: 🔢 Resolve Version
        id: version
        env:
          INPUT_VERSION: ${{ inputs.version }}
          INPUT_BUMP: ${{ inputs.bump }}
        run: |
          set -euo pipefail

          if [ "${{ github.ref_type }}" = "tag" ]; then
            VERSION="${{ github.ref_name }}"
            MODE="tag"
          elif [ -n "${INPUT_VERSION}" ]; then
            VERSION="${INPUT_VERSION}"
            MODE="dispatch"
          else
            # 取语义化排序后的最新 tag 作为基准，仓库里一个 tag 都没有时从 v0.0.0 起算
            # [EN] Base on the highest semver tag; start from v0.0.0 in a repo with no tags
            LATEST="$(git tag -l 'v*' --sort=-v:refname | head -n1)"
            [ -n "$LATEST" ] || LATEST="v0.0.0"
            BASE="${LATEST#v}"
            BASE="${BASE%%-*}"
            MAJOR="$(echo "$BASE" | cut -d. -f1)"
            MINOR="$(echo "$BASE" | cut -d. -f2)"
            PATCH="$(echo "$BASE" | cut -d. -f3)"
            MAJOR="${MAJOR:-0}"; MINOR="${MINOR:-0}"; PATCH="${PATCH:-0}"
            case "${INPUT_BUMP:-patch}" in
              major) VERSION="v$((MAJOR + 1)).0.0" ;;
              minor) VERSION="v${MAJOR}.$((MINOR + 1)).0" ;;
              *)     VERSION="v${MAJOR}.${MINOR}.$((PATCH + 1))" ;;
            esac
            echo "ℹ️ 基准 tag: ${LATEST} → 本次: ${VERSION}"
            MODE="dispatch"
          fi

          # 版本号必须是 vX.Y.Z[-prerelease]，否则 Go module 拒绝解析
          # [EN] Must be vX.Y.Z[-prerelease] or Go module resolution rejects it
          if ! echo "$VERSION" | grep -Eq '^v[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z.-]+)?$'; then
            echo "❌ 版本号格式非法: ${VERSION}（要求 vX.Y.Z 或 vX.Y.Z-rc.1）"
            exit 1
          fi

          PREV="$(git tag -l 'v*' --sort=-v:refname | grep -vx "$VERSION" | head -n1 || true)"

          # 顺带算出这次是 major / minor / patch，随 dispatch 一起发给下游
          # 下游（尤其是 TS SDK）需要这个级别来决定自己的 changeset 类型：协议破坏性
          # 变更对应 SDK 的 major，否则下游只能一律按 minor 发，版本号很快失真
          # 算在这里而不是让下游自己猜：只有协议中心同时知道新旧两个版本号
          #
          # [EN] Also derive whether this is a major / minor / patch bump and send it downstream
          # with the dispatch. Consumers (the TS SDK above all) need the level to choose their own
          # changeset type: a breaking contract change must become a major SDK release, otherwise
          # downstream has to guess and settles on minor forever, and its versions stop meaning
          # anything. It is computed here because only the hub knows both version numbers.
          semver_part() { echo "${1#v}" | cut -d- -f1 | cut -d. -f"$2"; }
          BUMP=minor
          if [ -n "$PREV" ]; then
            if [ "$(semver_part "$VERSION" 1)" -gt "$(semver_part "$PREV" 1)" ] 2>/dev/null; then
              BUMP=major
            elif [ "$(semver_part "$VERSION" 2)" -gt "$(semver_part "$PREV" 2)" ] 2>/dev/null; then
              BUMP=minor
            else
              BUMP=patch
            fi
          fi

          {
            echo "version=${VERSION}"
            echo "numeric=${VERSION#v}"
            echo "previous=${PREV}"
            echo "mode=${MODE}"
            echo "bump=${BUMP}"
          } >> "$GITHUB_OUTPUT"

          echo "📦 版本: ${VERSION}　上一个: ${PREV:-无（首次发布）}　级别: ${BUMP}　模式: ${MODE}"

      - name: 🐹 Setup Go
        uses: actions/setup-go@v6
        with:
          go-version-file: go.mod

      - name: 💾 Cache Protobuf Toolchain
        uses: actions/cache@v4
        with:
          path: |
            ~/go/bin
            ~/go/src
          key: pb-tools-${{ runner.os }}-${{ hashFiles('scripts/common.sh', 'scripts/setup-dependencies.sh', 'scripts/setup-protobuf-includes.sh') }}

      - name: 📥 Install Protobuf Dependencies
        run: bash scripts/setup-all.sh --no-pause

      - name: 🔧 Regenerate Everything
        run: bash scripts/generate-modular.sh

      - name: ✅ Verify Generated Code
        run: |
          go mod tidy
          go build ./...
          go test ./...

      - name: 🧮 Assert Artifacts Are In Sync
        # 发版的前提是「仓库里的 pb 就是 proto 生成出来的那一份」
        # 有 diff 说明有人改了 proto 没重新生成，或者手改了生成物：这种版本一旦发出去，
        # 下游 go get 到的代码和仓库里看到的 proto 对不上，排查成本极高，所以直接拦住
        #
        # [EN] A release presupposes that the committed pb really is what the protos generate.
        # A diff means someone changed a proto without regenerating, or hand-edited generated
        # code. Publishing that would make downstream `go get` disagree with the protos in the
        # repository, which is miserable to debug, so it is blocked here.
        run: |
          if git diff --quiet && git diff --cached --quiet; then
            echo "✅ 生成物与 proto 一致"
            exit 0
          fi
          echo "❌ 生成物与 proto 不一致，拒绝发版"
          git --no-pager diff --stat
          {
            echo "## ❌ 发版被拦截：生成物未同步"
            echo ""
            echo "本地执行 \`bash scripts/generate-modular.sh\` 并提交结果后重试"
            echo ""
            echo '```'
            git --no-pager diff --stat
            echo '```'
          } >> "$GITHUB_STEP_SUMMARY"
          exit 1

      - name: 📄 Build Release Assets
        id: assets
        env:
          VERSION: ${{ steps.version.outputs.version }}
          NUMERIC: ${{ steps.version.outputs.numeric }}
        run: |
          set -euo pipefail
          mkdir -p dist

          BUNDLE="docs/openapi.swagger.yaml"
          if [ ! -f "$BUNDLE" ]; then
            echo "❌ 缺少聚合文档 ${BUNDLE}，检查 proto/openapi/bundle.proto 是否存在"
            exit 1
          fi

          # 资产里的 info.version 对齐本次发布的版本号
          # 入库的那份保持 proto 里写死的值不变（否则每次发版都会产生一次无意义的
          # 提交，且与 generate-modular.sh 的输出不一致，pb 同步校验会一直报红）
          # 这里只改发出去的副本，改动范围限定在文件开头的 info 块
          #
          # [EN] Align info.version in the asset with the released version. The committed copy
          # keeps the value hardcoded in the proto, because rewriting it would create a pointless
          # commit per release and make the file disagree with what generate-modular.sh emits,
          # which would keep the sync check red. Only the published copy is touched, and only
          # inside the info block at the top of the file.
          sed -i "1,10s|^  version: .*|  version: ${NUMERIC}|" "$BUNDLE"
          cp "$BUNDLE" dist/openapi.swagger.yaml
          echo "ℹ️ 聚合文档 info：" && head -6 dist/openapi.swagger.yaml
          grep -q "^  version: ${NUMERIC}$" dist/openapi.swagger.yaml || {
            echo "❌ 版本号没写进聚合文档，检查 info 块的格式是否变了"
            exit 1
          }

          # 按模块拆分的 yaml 也一并发出去：有的团队要按服务单独生成客户端
          # [EN] Ship the per-module yaml files too: some teams generate per-service clients
          # 用 tar -T 读文件清单，而不是 tar ... $(find ...)：后者依赖未加引号的变量
          # 按空白分词，文件名里有空格就会散架，而且在不同 shell 下行为不一致
          # [EN] tar -T reads a file list instead of relying on an unquoted $(find ...) splitting
          # on whitespace, which breaks on filenames containing spaces and behaves differently
          # between shells
          find proto -name '*.swagger.yaml' | sort > dist/spec-list.txt
          if [ ! -s dist/spec-list.txt ]; then
            echo "❌ 未找到任何按模块拆分的 swagger 文件"
            exit 1
          fi
          tar -czf "dist/openapi-specs-${VERSION}.tar.gz" -T dist/spec-list.txt
          rm -f dist/spec-list.txt

          {
            echo "bundle=dist/openapi.swagger.yaml"
            echo "specs=dist/openapi-specs-${VERSION}.tar.gz"
          } >> "$GITHUB_OUTPUT"
          ls -la dist/

      - name: 📝 Compose Release Notes
        id: notes
        env:
          VERSION: ${{ steps.version.outputs.version }}
          PREV: ${{ steps.version.outputs.previous }}
        run: |
          set -euo pipefail
          MODULE="$(head -1 go.mod | awk '{print $2}')"
          NOTES=dist/RELEASE_NOTES.md

          {
            echo "## 📦 引用方式 | How to consume"
            echo ""
            echo "**Go 服务 | Go services**"
            echo ""
            echo '```bash'
            echo "go get ${MODULE}@${VERSION}"
            echo '```'
            echo ""
            echo "**TypeScript / 其它语言 SDK | TypeScript and other SDKs**"
            echo ""
            echo "下载本 Release 的 \`openapi.swagger.yaml\`（全部服务的聚合文档）喂给生成器；"
            echo "只要某一个服务的文档，用 \`openapi-specs-${VERSION}.tar.gz\` 里按模块拆分的 yaml"
            echo ""
            echo "Download this release's \`openapi.swagger.yaml\` (every service in one document) and"
            echo "feed it to your generator; for a single service use the per-module yaml files inside"
            echo "\`openapi-specs-${VERSION}.tar.gz\`."
            echo ""
          } > "$NOTES"

          if [ -z "$PREV" ]; then
            echo "## 🎉 首次发布 | First release" >> "$NOTES"
            echo "" >> "$NOTES"
          else
            echo "## 🔍 协议变更 | Contract changes（${PREV} → ${VERSION}）" >> "$NOTES"
            echo "" >> "$NOTES"

            CHANGED="$(git diff --name-only "${PREV}..HEAD" -- 'proto/**/*.proto' 'proto/*.proto' || true)"
            if [ -z "$CHANGED" ]; then
              echo "本次发布没有 proto 文件变更（可能只是生成链路或文档调整）" >> "$NOTES"
              echo "" >> "$NOTES"
            else
              {
                echo '```'
                echo "$CHANGED"
                echo '```'
                echo ""
              } >> "$NOTES"
            fi

            # 不兼容变更的粗筛：删掉的 rpc / 删掉的 message / 改过的字段号
            # 这不是 buf breaking 那种严谨的兼容性分析，只是把最容易出事的三类改动
            # 捞出来贴在发布说明顶部，让 review 的人决定该不该升 major
            # 判定依据是 diff 的删除行，所以重命名也会被报出来，这是有意为之
            #
            # [EN] A coarse screen for incompatible changes: removed rpcs, removed messages and
            # touched field numbers. This is not rigorous compatibility analysis like buf breaking;
            # it surfaces the three most dangerous kinds of edit at the top of the notes so a human
            # decides whether a major bump is warranted. It reads deleted diff lines, so renames
            # show up too, which is intentional.
            BREAKING="$(git diff -U0 "${PREV}..HEAD" -- 'proto/**/*.proto' 'proto/*.proto' \
              | grep -E '^-[^-]' \
              | grep -E '(^-\s*rpc\s|^-\s*message\s|^-\s*enum\s|=\s*[0-9]+\s*;)' || true)"
            if [ -n "$BREAKING" ]; then
              {
                echo "### ⚠️ 可能的不兼容变更 | Possibly breaking"
                echo ""
                echo "以下删除行涉及 rpc / message / 字段号，升级 major 版本前请人工确认："
                echo "The deleted lines below touch rpcs, messages or field numbers; confirm before"
                echo "treating this as a compatible release."
                echo ""
                echo '```diff'
                echo "$BREAKING" | head -60
                echo '```'
                echo ""
              } >> "$NOTES"
            fi

            {
              echo "## 📋 提交明细 | Commits"
              echo ""
              git log --no-merges --pretty='- %s (%h)' "${PREV}..HEAD" | head -80
              echo ""
            } >> "$NOTES"
          fi

          cat "$NOTES" >> "$GITHUB_STEP_SUMMARY"
          echo "module=${MODULE}" >> "$GITHUB_OUTPUT"
          echo "file=${NOTES}" >> "$GITHUB_OUTPUT"

      - name: 🏷️ Create Tag
        if: ${{ steps.version.outputs.mode == 'dispatch' && env.DRY_RUN != 'true' }}
        env:
          VERSION: ${{ steps.version.outputs.version }}
        run: |
          set -euo pipefail
          if git rev-parse -q --verify "refs/tags/${VERSION}" >/dev/null; then
            echo "ℹ️ tag ${VERSION} 已存在，跳过创建"
            exit 0
          fi
          git config user.name "github-actions[bot]"
          git config user.email "github-actions[bot]@users.noreply.github.com"
          git tag -a "${VERSION}" -m "📦 release: ${VERSION}" -m "协议中心发版 | contract-hub release"
          git push origin "refs/tags/${VERSION}"
          echo "🏷️ 已创建并推送 tag ${VERSION}"

      - name: 🚀 Publish GitHub Release
        if: ${{ env.DRY_RUN != 'true' }}
        env:
          GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}
          VERSION: ${{ steps.version.outputs.version }}
          NOTES: ${{ steps.notes.outputs.file }}
          BUNDLE: ${{ steps.assets.outputs.bundle }}
          SPECS: ${{ steps.assets.outputs.specs }}
        run: |
          set -euo pipefail
          if gh release view "${VERSION}" >/dev/null 2>&1; then
            echo "ℹ️ Release ${VERSION} 已存在，改为更新说明与资产"
            gh release edit "${VERSION}" --notes-file "${NOTES}"
            gh release upload "${VERSION}" "${BUNDLE}" "${SPECS}" --clobber
          else
            gh release create "${VERSION}" \
              --title "${VERSION}" \
              --notes-file "${NOTES}" \
              "${BUNDLE}" "${SPECS}"
          fi
          echo "🚀 Release ${VERSION} 已发布"

      - name: 🔥 Warm Go Module Proxy
        if: ${{ env.DRY_RUN != 'true' }}
        env:
          MODULE: ${{ steps.notes.outputs.module }}
          VERSION: ${{ steps.version.outputs.version }}
        # 让公共代理先把这个版本抓一遍，下游 go get 立刻能解析到
        # 私有仓库代理抓不到，所以失败不算错（下游会走 GOPRIVATE 直连）
        # [EN] Prime the public proxy so downstream `go get` resolves immediately. A private
        # repository cannot be fetched by the proxy, so a failure here is not an error:
        # downstream resolves it directly through GOPRIVATE.
        continue-on-error: true
        run: |
          echo "ℹ️ 预热 ${MODULE}@${VERSION}"
          GOFLAGS=-mod=mod GOPROXY=https://proxy.golang.org go list -m "${MODULE}@${VERSION}" \
            || echo "⚠️ 公共代理未能抓取（私有仓库属正常），下游请配置 GOPRIVATE=${MODULE}"

      # ----------------------------------------------------------------------
      # 通知下游 | Notify downstream
      #
      # 发完版主动推一把，而不是等下游自己轮询：协议改了但服务没升级，是这类架构
      # 最常见的事故来源推送用 repository_dispatch，下游仓库各自决定怎么响应
      # （Go 服务升 go.mod、TS SDK 重新生成并发 npm）
      #
      # GITHUB_TOKEN 不能跨仓库触发，所以这里需要一个 GitHub App token
      # 没配 App 时整段跳过，发版本身不受影响
      #
      # [EN] Push rather than let downstream poll: a changed contract with un-upgraded services
      # is the classic failure of this architecture. The push is a repository_dispatch and each
      # downstream repo decides how to react (Go services bump go.mod, the TS SDK regenerates and
      # publishes to npm). GITHUB_TOKEN cannot trigger across repositories, so a GitHub App token
      # is needed; without the App configured the whole section is skipped and the release itself
      # is unaffected.
      # ----------------------------------------------------------------------
      - name: 🔑 Mint Dispatch Token
        id: dispatch-token
        if: ${{ env.DRY_RUN != 'true' && env.OPS_CLI_APP_ID != '' }}
        uses: actions/create-github-app-token@v2
        with:
          app-id: ${{ secrets.OPS_CLI_APP_ID }}
          private-key: ${{ secrets.OPS_CLI_APP_PRIVATE_KEY }}
          owner: ${{ github.repository_owner }}

      - name: 🛰️ Notify Downstream Consumers
        if: ${{ env.DRY_RUN != 'true' && steps.dispatch-token.outputs.token != '' }}
        env:
          GH_TOKEN: ${{ steps.dispatch-token.outputs.token }}
          VERSION: ${{ steps.version.outputs.version }}
          MODULE: ${{ steps.notes.outputs.module }}
          BUMP: ${{ steps.version.outputs.bump }}
          # 下游 Go 服务仓库，逗号分隔；仓库变量 DOWNSTREAM_REPOS 优先于模板默认值，
          # 这样加一个新服务不需要重新渲染模板
          # [EN] Comma-separated downstream Go service repositories; the DOWNSTREAM_REPOS
          # repository variable wins over the template default, so adding a service needs no re-render
          DOWNSTREAM_REPOS: ${{ vars.DOWNSTREAM_REPOS || '<% .DownstreamRepos %>' }}
          SDK_REPO: ${{ vars.SDK_REPO || '<% .SdkRepo %>' }}
        run: |
          set -euo pipefail
          OWNER="${{ github.repository_owner }}"
          SENT=0

          # 用 JSON body 而不是 gh 的 -f key[sub]=value 嵌套写法：后者在不同 gh 版本上
          # 对 client_payload 这种嵌套对象的处理并不一致，JSON 没有歧义
          # [EN] A JSON body instead of gh's -f key[sub]=value nesting, whose handling of a
          # nested object like client_payload varies between gh versions; JSON is unambiguous
          dispatch() {
            local repo="$1" event="$2"
            case "$repo" in */*) ;; *) repo="${OWNER}/${repo}" ;; esac
            echo "🛰️ ${event} → ${repo}"
            if gh api "repos/${repo}/dispatches" --method POST --input - >/dev/null <<JSON
          {
            "event_type": "${event}",
            "client_payload": {
              "version": "${VERSION}",
              "module": "${MODULE}",
              "repository": "${GITHUB_REPOSITORY}",
              "bump": "${BUMP}"
            }
          }
          JSON
            then
              echo "  ✅ 已送达"
              SENT=$((SENT + 1))
            else
              echo "  ⚠️ 送达失败（检查 App 是否安装到 ${repo}）"
            fi
          }

          IFS=',' read -ra REPOS <<< "${DOWNSTREAM_REPOS}"
          for repo in "${REPOS[@]}"; do
            repo="$(echo "$repo" | tr -d '[:space:]')"
            [ -n "$repo" ] || continue
            dispatch "$repo" proto-released
          done

          # 不写成 [ -n "$SDK" ] && dispatch ...：set -e 下这行在 SDK 为空时
          # 会以非零退出码结束整个 step
          # [EN] Not written as `[ -n "$SDK" ] && dispatch ...`: under set -e that line exits
          # the whole step non-zero whenever SDK is empty
          if [ -n "$SDK" ]; then
            dispatch "$SDK" proto-released
          fi

          echo "📣 共通知 ${SENT} 个仓库" >> "$GITHUB_STEP_SUMMARY"

      - name: 📢 Notify Lark
        if: ${{ always() && env.DRY_RUN != 'true' }}
        uses: <% .PipelineRepo %>/.github/actions/notify@master
        env:
          FEISHU_WEBHOOK_URL: ${{ secrets.FEISHU_WEBHOOK_URL }}
        with:
          provider: feishu
          status: ${{ job.status == 'success' && 'success' || 'failure' }}
          title: ${{ job.status == 'success' && format('📦 协议已发版 {0}', steps.version.outputs.version) || format('❌ 协议发版失败 {0}', steps.version.outputs.version) }}
          message: |
            **模块**：`${{ steps.notes.outputs.module }}@${{ steps.version.outputs.version }}`
            **上一版**：${{ steps.version.outputs.previous || '无（首次发布）' }}
            **引用**：`go get ${{ steps.notes.outputs.module }}@${{ steps.version.outputs.version }}`
            **Release**：${{ github.server_url }}/${{ github.repository }}/releases/tag/${{ steps.version.outputs.version }}
