# 🔀 Cross Commit Action

[![Codacy Badge](https://app.codacy.com/project/badge/Grade/c7cb45e298d344708128c09490a2d8a3)](https://www.codacy.com/gh/StirlingLabs/CrossCommitAction/dashboard?utm_source=github.com&amp;utm_medium=referral&amp;utm_content=StirlingLabs/CrossCommitAction&amp;utm_campaign=Badge_Grade)

> Synchronises parts of repositories. Typical usage is for synchronizing to GitOps state repositories from source code.

## 🚀 Quickstart

```yaml
steps:
- name: Commit to state repository
  uses: StirlingLabs/CrossCommitAction@v21.07.0
  with:
    source-folder: config
    destination-repository: https://<user>:${{ secrets.user_token }}@github.com/org/dest-repo
    destination-folder: .
    destination-branch: alpha
    git-commit-message: "Custom commit message"
    git-commit-sign-off: "false"
    excludes: |
      README.md
      .git
      path/deeper/in/the/repo
```

The example above will trigger `rsync` that will synchronize the files in
`./config` to repository `github.com/org/dest-repo` root using user credentials
(can be stored as Github secrets) and create commit on `alpha` branch. The
`rsync` will exclude `/.git`, `/README.md` and `/path/deeper/in/the/repo` from
both repositories during the synchronization.

## Parameters

|Name|Function|
|-|-|
|source-folder|Sub folder of the repository to copy.|
|destination-repository|Repository to be commited to. In case of private repository, specify the full URL in the form user:path@url (using a secret for the access token or password, as above).|
|destination-folder|Sub folder of the destingation repository to copy into.|
|destination-branch|Branch of the destination repository to use.|
|git-commit-message|Optional message to be used the in the git commit.|
|git-commit-sign-off|Requires sign-off|
|authorized-user|If a protected repo, the username of someone with commit permissions to the repo.|
|authorized-user-secret|"A personal access token or secret for the user giving commit permissions.|
|excludes|Optionally exclude some directories from being synced. If you require multiple values, use the pipe character \| and have one value per line.|
