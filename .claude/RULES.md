FlClashR — Rules for Claude

These rules are FOR CLAUDE. Every session must follow them. Violating any rule marked CRITICAL will break the build, crash the app, or corrupt the VPN.


Rule 0: Read This First (ALWAYS)

Before ANY code change:
1. Read SESSION_CONTEXT.md — understand current state
2. Read ARCHITECTURE.md — understand why things are the way they are
3. Check if the change violates any architecture decision
4. Ask yourself: "Has this been tried before and failed?"


Rule 1: FFI Architecture (CRITICAL)
DO:
✅ Use _MainFFIHandler for all FFI calls from main engine
✅ Check dartApiInitialized flag before calling initNativeApiBridge
✅ Keep _service() entrypoint MINIMAL

DON'T:
❌ Use IsolateNameServer for cross-engine communication
❌ Call Dart_InitializeApiDL twice (WILL crash with SIGSEGV)
❌ Add ClashLibHandler initialization in _service()
❌ Add IPC channels between engines (they're different Dart VMs)
Rule 2: Controller & Scaffold (CRITICAL)
DO:
✅ Call _setupClashConfig() directly from setupClashConfig()
✅ Check that SimpleHomeView is the active view before adding guards

DON'T:
❌ Use homeScaffoldKey.currentState — it's always null
❌ Add CommonScaffold dependency
❌ Guard VPN init behind Scaffold state checks
Rule 3: Proxy Rules (CRITICAL)
DO:
✅ Put specific rules BEFORE MATCH,DIRECT
✅ Keep MATCH,DIRECT as the VERY LAST rule
✅ Place DST-PORT,443,REJECT,udp BEFORE MATCH but AFTER service rules
✅ Test rule ordering: think "does this rule get reached?"

DON'T:
❌ Put MATCH,DIRECT anywhere except last position
❌ Add rules after MATCH (they'll never execute)
❌ Remove QUIC block (DST-PORT,443,REJECT,udp)
Rule 4: Go/FFI Layer
DO:
✅ Check nil on all pointers in lib_android.go
✅ Guard initNativeApiBridge with boolean flag
✅ Test Go changes by rebuilding libclash.so

DON'T:
❌ Remove nil guards in handleStartTun
❌ Remove dartApiInitialized flag
❌ Assume Go changes work without .so rebuild
Rule 5: File Changes
DO:
✅ Show diffs for small changes (instead of full files)
✅ Say "this file is unchanged" to save tokens
✅ List ALL files affected before writing code

DON'T:
❌ Rewrite unchanged files
❌ Touch core/*.go without explicit permission
❌ Modify android/build.gradle.kts without asking
Rule 6: Before Committing Code
MANDATORY CHECKLIST:
□ Does it compile? (imagine flutter build apk path)
□ Does it break _service() entrypoint?
□ Does it call initNativeApiBridge twice?
□ Does it add homeScaffoldKey dependency?
□ Does it reorder proxy rules incorrectly?
□ Is there a test for the new code?
□ Is SESSION_CONTEXT.md updated?
Rule 7: Error Response Protocol
IF BUILD FAILS:
1. Read the error log FIRST (don't guess)
2. Identify the EXACT file and line
3. Check if it's a known issue (search CHANGELOG.md)
4. Propose fix with explanation
5. After fix: run through Rule 6 checklist

IF VPN CRASHES:
1. Check if initNativeApiBridge was called twice
2. Check if _service() was modified
3. Check if FFI architecture was violated
4. Look at logcat for SIGSEGV
Rule 8: Testing
DO:
✅ Write tests for new logic (test/ mirroring lib/)
✅ Test VPN start/stop cycle (3 times)
✅ Test subscription import with valid AND invalid data
✅ Test rule ordering: verify specific rules fire before MATCH

DON'T:
❌ Skip tests because "it's a small change"
❌ Test only the happy path
❌ Assume existing tests still pass
Rule 9: Token Efficiency
To save tokens (user pays per token):
1. NEVER output unchanged files — say "no changes needed for X"
2. Use diff format for single-function changes
3. Keep SESSION_CONTEXT.md under 300 lines
4. Use grep/read tools to inspect files instead of asking user to paste
5. State conclusions FIRST, then explain (inverted pyramid)
Rule 10: Communication
DO:
✅ Start with SPEC: "I will change X to fix Y by modifying Z"
✅ Show changes as diffs when appropriate
✅ Flag CRITICAL violations immediately
✅ Update SESSION_CONTEXT.md at end of session

DON'T:
❌ Write code without stating what it does
❌ Hide assumptions — state them explicitly
❌ End session without updating context files
❌ Ask permission for obvious fixes (just fix them)


4. В начале каждой сессии с Claude:

Прочитай .claude/SESSION_CONTEXT.md и .claude/RULES.md.
Задача: [опиши что нужно сделать]

5. В конце каждой сессии:

Обнови SESSION_CONTEXT.md и CHANGELOG.md с учётом сделанных изменений.

Файлы готовы к коммиту. Хочешь что-то докрутить в RULES.md (например, добавить специфичные для твоего стека правила тестирования) или добавить секцию в SESSION_CONTEXT.md про текущую проблему с YouTube/Telegram?
