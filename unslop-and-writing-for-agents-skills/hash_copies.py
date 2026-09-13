import re, subprocess, hashlib, base64, json, collections
src = open('/Users/aaron/.claude/projects/-Users-aaron-Code-agents-wellactually/30bdb2b2-81bf-494e-be79-ba566b29abb0/tool-results/bi8qeaxcm.txt').read()
repos = re.findall(r'^([\w.-]+/[\w.-]+) (writing-for-agents/SKILL\.md)$', src, re.M)
head = hashlib.md5(open('mp-head.md','rb').read()).hexdigest()
groups = collections.defaultdict(list)
for repo, path in repos:
    try:
        out = subprocess.run(['gh','api',f'repos/{repo}/contents/{path}','--jq','.content'],capture_output=True,text=True,timeout=30).stdout
        body = base64.b64decode(out)
        h = hashlib.md5(body).hexdigest()
        groups[h].append((repo, len(body)))
        open(f'copy-{repo.replace("/","__")}.md','wb').write(body)
    except Exception as e:
        groups['ERR'].append((repo,str(e)))
print('head', head)
for h, rs in sorted(groups.items(), key=lambda kv:-len(kv[1])):
    print(h, 'SAME-AS-HEAD' if h==head else '', len(rs), rs)
