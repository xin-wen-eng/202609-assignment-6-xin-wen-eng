---
title: "Assignment 6: Choosing the Right EC2 Instance Type"
---

# Assignment 6: Choosing the Right EC2 Instance Type

## Objective

Modules 4-5 had you build infrastructure to a precise specification. This assignment is different: you're given a workload description, and you decide what EC2 instance type actually fits it — then you have to defend that decision in writing.

You'll deploy two hosts for a small AI-application company's infrastructure:

- **Host A ("api")**: a public-facing API tier
- **Host B ("worker")**: a private, internal batch-processing worker

Both run the same simple Python service (provided), reusing the VPC design from Assignment 5 where  Host A takes the old bastion's public-subnet role, Host B takes the private host's role, same isolation model, same live-HTTP-proxy grading pattern.

Your job is not to write new networking or app code. It's to read two workload specs, choose an appropriate instance type for each, write the Terraform to deploy them, and justify your choices.

**AI Tools:** You're encouraged to use an AI assistant as part of your research process here — this module's "Agentic AI: Choosing the Right Instance Type" content is directly about this. If you do, `JUSTIFICATION.md` asks you to briefly describe what you asked and what you specifically verified before accepting the recommendation.

## The Workloads

### Host A: Prompt Optimizer API

A public REST API for an early-stage AI-application product (the same Prompt Optimizer concept from Assignments 2 and 4).

| Metric | Value |
|---|---|
| Traffic volume | ~250,000 requests/day |
| Traffic pattern | Bursty — business-hours peak (9am-6pm) runs ~10x the overnight rate |
| Average CPU utilization | 8-12% during peak, under 2% overnight |
| Per-process memory footprint | ~150MB |
| Latency budget | Under 100ms per request |
| Business context | Early-stage product — cost efficiency matters; over-provisioning is an explicit concern |

### Host B: Embedding Batch Regeneration Worker

An internal batch job that regenerates vector embeddings for stored documents. No public exposure, no external callers.

| Metric | Value |
|---|---|
| Schedule | Once nightly at 2am |
| Duration | Continuous 45-60 minute run |
| Volume | ~50,000 documents processed per run |
| CPU utilization | **Sustained** 85-95% for the entire run — flat, not bursty |
| Working memory | ~2GB |
| Public exposure | None — internal only |

## What's Provided

### Files Provided Complete — Do Not Modify these files

- **`app/server.py`** — the service both hosts run. Exposes `/healthcheck` (both hosts), `/check-private` and `/check-batch` (api host only — proxy endpoints Gradescope uses to verify the worker), and `/batch-job` (worker host only — a trivial deterministic computation standing in for real batch work). Uses only the Python standard library — no `pip install` required, since the worker host has no internet access (no NAT Gateway, same isolation model as Assignment 5).
- **`terraform/versions.tf`** — Terraform and AWS provider configuration.
- **`terraform/ami.tf`** — AMI lookups for both x86_64 and arm64 architectures, using the SSM parameter technique from the Module 6 CLI walkthrough. You'll pick whichever matches the instance type you choose — see "Choosing Graviton (ARM) vs. x86_64" below.
- **`terraform/network.tf`, `terraform/subnets.tf`, `terraform/security_groups.tf`, `terraform/nacls.tf`** — the same VPC design from Assignment 5 (public/private subnet, matching isolation model), renamed generically (`api_sg`/`worker_sg` instead of `bastion_sg`/`private_sg`). Full spec below.
- **`terraform/scripts/user_data.sh.tpl`** — the boot script both instances share.
- **`terraform/variables.tf`** — declares `key_name`, `api_instance_type`, and `worker_instance_type` (no defaults for the instance types — that's your decision, supplied via `terraform.tfvars`).
- **`terraform/outputs.tf`** — outputs Gradescope reads (`api_public_ip`, `worker_private_ip`), plus your chosen instance types and AMI IDs (`api_instance_type`, `worker_instance_type`, `api_ami_id`, `worker_ami_id`) — run `terraform output` after apply for a quick summary of what you actually deployed.
- **`.github/workflows/deploy.yml.example`** — the deployment workflow. You'll rename this file to activate it (see step 4 below), but do not edit the file.
- **`.gitignore`** — already configured correctly, including keeping `terraform.tfstate` committed (required for grading).

Modifying any of these will cost you credit — see Deductions below.

### Files You Create, Complete, or Change

- **`terraform/compute.tf`** — a skeleton with requirements as comments. This is the core of your work: two `aws_instance` resources, using the instance types and AMIs you choose.
- **`terraform/terraform.tfvars`** — you create this by copying `terraform/terraform.tfvars.example` and filling in your key pair name and your two chosen instance types.
- **`JUSTIFICATION.md`** — a template is provided in the repo root; you fill in your reasoning and cost comparison for both hosts. Manually graded, 10 of your 20 points.
- **`.github/workflows/deploy.yml`** — you create this by renaming `deploy.yml.example` (removing the `.example` extension) to activate the deployment workflow.

### Infrastructure Specification (for your reference)

**VPC and Subnets**

| Resource | Value |
|---|---|
| VPC CIDR | `172.20.0.0/16` |
| Public subnet (`aws_subnet.public`) | `172.20.1.0/24`, us-west-2a, auto-assigns public IPs |
| Private subnet (`aws_subnet.private`) | `172.20.2.0/24`, us-west-2a, does NOT auto-assign public IPs |
| Internet Gateway | Attached to the VPC |
| Public route table | `172.20.0.0/16` → local, `0.0.0.0/0` → Internet Gateway |
| Private route table | `172.20.0.0/16` → local only — **no route to the internet at all** |

**Security Groups**

| Security Group | Direction | Port(s) | Source/Destination |
|---|---|---|---|
| `api_sg` (api host) | Inbound | 22 (SSH) | `0.0.0.0/0` |
| `api_sg` (api host) | Inbound | 80 (HTTP) | `0.0.0.0/0` |
| `api_sg` (api host) | Outbound | 22, 80 | `172.20.2.0/24` (private subnet CIDR) |
| `worker_sg` (worker host) | Inbound | 22 (SSH) | `api_sg` (security group reference, not a CIDR) |
| `worker_sg` (worker host) | Inbound | 80 (HTTP) | `api_sg` (security group reference, not a CIDR) |
| `worker_sg` (worker host) | Outbound | none | Security Groups are stateful — no egress rule is needed for replies to the inbound traffic above |

**Network ACLs**

The public subnet is left on its **default NACL** (allows all traffic) — no custom NACL is needed there. The private subnet has a custom NACL (`private_nacl`):

| Direction | Port(s) | Source/Destination |
|---|---|---|
| Inbound | 22, 80 | `172.20.1.0/24` (public subnet CIDR) |
| Inbound | 1024-65535 (ephemeral) | `172.20.1.0/24` |
| Outbound | 1024-65535 (ephemeral) | `172.20.1.0/24` |

No rule in either direction references `0.0.0.0/0` — the private subnet has no path to the internet, full stop. This is also why `app/server.py` is written to use only the Python standard library: the worker host cannot reach PyPI to `pip install` anything.

**Putting it together**: the api host is reachable from the internet on ports 22 and 80; it can reach the worker host on 22/80; the worker host can be reached only from the api host, on ports 22 and 80, and cannot initiate or receive any other traffic, internet-bound or otherwise.

## What You Need to Do

### 1. Choose your instance types

Read the two workload specs above. Decide on an instance type for each host. You'll need to reference:
- The Module 6 slides on instance families and pricing models
- The AWS EC2 Instance Types documentation
- Optionally, an AI assistant — see the note in the Objective section above

### Choosing Graviton (ARM) vs. x86_64 — and the matching AMI

Once you've picked instance types in the previous step, you need to know which CPU architecture each one runs on, because that decides which AMI it boots from.

**How to tell which architecture an instance type uses:** look at the family name, right after the generation number.
- Ends in **"g"** → **Graviton**, which is AWS's own **arm64** (ARM64/aarch64) processor. Examples: `t4g`, `c6g`, `c7g`, `m6g`, `r6g`.
- No trailing "g" → **x86_64** (Intel or AMD). Examples: `t3`, `c5`, `c6i`, `m5`, `r5`.

Note: with an **"i" suffix (e.g. `c6i`) means Intel, not Graviton** — that's still x86_64, not arm64. The "g" is the only letter that signals Graviton/ARM.

**The two AMIs are already looked up for you**, in `terraform/ami.tf` (provided, do not modify):

| Your instance type is... | Use this in `compute.tf`'s `ami =` |
|---|---|
| x86_64 (e.g. `t3.micro`, `c6i.large`) | `data.aws_ssm_parameter.ubuntu_amd64.value` |
| Graviton/ARM (e.g. `t4g.micro`, `c6g.large`) | `data.aws_ssm_parameter.ubuntu_arm64.value` |

Your two hosts don't need to match each other's architecture — it's entirely fine (and a legitimate cost/performance tradeoff to discuss in `JUSTIFICATION.md`) to put the api host on Graviton and the worker host on x86_64, or any other combination. Each `aws_instance` resource just needs to reference the AMI that matches *its own* instance type.

**Checking your own work before you `apply`:** after `terraform plan`, look at the `instance_type` and `ami` values Terraform shows for each resource — a mismatch is worth catching here rather than after a boot failure. The autograder also runs this same cross-check automatically, using the two AMI IDs recorded in your `terraform.tfstate`, and will tell you specifically if it detects an architecture mismatch.

### 2. Write `terraform/compute.tf`

Full requirements are in the file's comments. In short: two `aws_instance` resources (`api` and `worker`), each using the AMI that matches your chosen instance type's architecture (x86_64 vs. arm64 — Graviton/ARM instance type names end in "g", e.g. t4g, c6g, m6g), attached to the correct subnet and security group, with the shared `user_data` pattern.

### 3. Write `JUSTIFICATION.md`

A template is provided in the repo root. For each host, explain: the workload characteristics that drove your decision, why that instance family fits, why you didn't choose an alternative, and a **cost comparison** — the actual On-Demand hourly/monthly rate for your choice versus at least one alternative, using the AWS Pricing Calculator or an AI assistant. This is worth 10 of your 20 points and is graded manually — a correct deployment with a weak or missing justification will not receive full credit.

### 4. Deploy and submit

1. Copy `terraform/terraform.tfvars.example` to `terraform/terraform.tfvars` and fill in your key pair name and chosen instance types.
2. Add `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY` as GitHub repository secrets.
3. Rename `.github/workflows/deploy.yml.example` to `deploy.yml`.
4. Commit and push. Watch the Actions tab — a successful run deploys both instances and commits the updated `terraform.tfstate` back to your repo.
5. Submit on Gradescope (GitHub-linked submission).
6. Once Gradescope confirms a pass, you can destroy your terraform resources.
   a. First, you need to update your local repository with the updated `terraform.tfstate` file from the remote github repo. To do this, run `git pull`.
   b. You can now run the the  `terraform destroy` to remove all of your terraform deployed resources from your AWS account.

You may resubmit as many times as needed before the deadline, but always make sure you remove all resources before running Gradescope again.  Please make sure all instances are terminated after you are completed (just check the AWS console).

## Testing and Debugging with Terraform

A quick refresher on the Terraform commands you'll use for this assignment. Running these locally, yourself, before pushing is almost always faster than waiting on the GitHub Actions pipeline to fail and reading through its logs.

### `terraform init`

Downloads the AWS provider. Run once per project, or again if you change provider requirements.

```bash
cd terraform
terraform init
```

### `terraform validate`

Checks your HCL syntax without touching AWS or creating anything. Fast — run this after every edit to `compute.tf`.

```bash
terraform validate
```

### `terraform plan`

Shows exactly what Terraform intends to create, without creating anything. This is the best place to catch a mistake before it costs you several minutes waiting for instances to boot.

```bash
terraform plan
```

Look at the plan output for your two `aws_instance` resources — confirm the `ami` and `instance_type` values are what you actually intended before applying.

### `terraform apply`

Actually creates the resources. Run without any flags, it shows the same plan and asks you to type `yes` to confirm — this is a safety net, not a formality. (GitHub Actions runs this with `-auto-approve` instead, since there's no one there to type `yes`.)

```bash
terraform apply
```

### `terraform output`

After a successful apply, this prints the values from `outputs.tf` — a quick way to confirm what actually got deployed, without opening the AWS Console.

```bash
terraform output
```

Example:

```text
api_ami_id           = <sensitive>
api_instance_type    = "t3.micro"
api_public_ip        = "54.123.45.67"
worker_ami_id        = <sensitive>
worker_instance_type = "t3.large"
worker_private_ip    = "172.20.2.10"
```

`api_ami_id` and `worker_ami_id` are intentionally masked as `<sensitive>` here — this is a Terraform/AWS-provider requirement (the provider flags all SSM parameter values as potentially sensitive, even a public AMI ID), not a sign anything is wrong. If you need to actually see an AMI ID — e.g. to double-check it matches your instance type's architecture — run:

```bash
terraform output -raw api_ami_id
terraform output -raw worker_ami_id
```

You generally shouldn't need to do this by hand: the autograder already cross-references each host's `instance_type` against its `ami` directly from your committed `terraform.tfstate`, and will call out a specific architecture mismatch (Graviton instance type paired with the x86_64 AMI, or vice versa) in its feedback if it finds one.

### `terraform destroy`

Tears down everything this configuration created. Use this once Gradescope has confirmed a passing score, so you stop paying for the instances.

```bash
terraform destroy
```

### A note on local `apply` vs. GitHub Actions

You're welcome to run `terraform apply` locally to test end-to-end before pushing. Just keep in mind: whoever applies last "wins" and produces the `terraform.tfstate` that ends up committed. If you apply locally and then push, GitHub Actions will apply again (usually a no-op if nothing changed since your local apply) and will be the one to commit the resulting state file — that's expected, not a bug.

---

## Testing Your Deployment Manually

Once `terraform apply` succeeds, you can check if everything is working manually.   These are the same checks the autograder runs, and running them yourself first will tell you exactly wh  ere to look if something's wrong.

### 1. Get your IPs

```bash
terraform output api_public_ip
terraform output worker_private_ip
```

### 2. Confirm the api host is up

```bash
curl http://<api_public_ip>/healthcheck
```

Expected: `{"status": "ok", "host": "api"}`

If this fails, the problem is with the api host itself or `api_sg` — not yet a worker/network issue.

### 3. Confirm the api host can reach the worker

```bash
curl "http://<api_public_ip>/check-private?target=<worker_private_ip>"
```

Expected: `{"status": "ok", "host": "worker"}`

If step 2 passed but this times out or returns a 502, the api host itself is fine — the problem is specifically in the path between the two hosts. Check, in order: `work  er_sg`'s inbound rule (does it actually reference `api_sg`?), and `private_nacl`'s rules (both directions — remember NACLs are stateless).

### 4. Confirm the worker's actual job endpoint works

```bash
curl "http://<api_public_ip>/check-batch?target=<worker_private_ip>"
```

Expected: `{"host": "worker", "a": 15, "b": 27, "result": 42}`

This is exactly what Gradescope's last live check verifies. If step 3 passed but this doesn't, the network path is fine — something's wrong with the worker's `app.servic  e` itself.

### 5. `nc` — isolating network problems from application problems

If a `curl` hangs or fails and you're not sure whether it's a network issue (Security Group/NACL) or an application issue (service not running), The  `nc` command tests just the port  , with no application-level request involved:

```bash
nc -zv <worker_private_ip> 80
```

If `nc` says the port is open but `curl` still fails, the networking is fine — look at the application. If `nc` says the port is closed or times out, it's a Security Gro  up or NACL problem, not the app.

### 6. SSH in directly, if you need to look closer

You can SSH to the api host with your own key pair:

```bash
ssh -i <path-to-key>.pem ubuntu@<api_public_ip>
```

Since the worker has no public IP, reach it from your own machine in one step with `ssh -J` (`ProxyJump`).  Note that this doesn't always work between Ubuntu and Windows ssh version. YMMV. 

```bash
ssh -J ubuntu@<api_public_ip> ubuntu@<worker_private_ip>
```

Once connected to either host, useful commands for digging into a problem:

```bash
sudo systemctl status app.service      # is the service running?
sudo journalctl -u app.service -n 50   # recent logs - did user_data or the app itself error out?
curl http://localhost/healthcheck      # test the app locally, bypassing the network entirely
```

---

## Submission (Gradescope)

The autograder checks:

1. **API host instance type** — evaluated against the workload characteristics described above. Not every instance family will score full credit.
2. **Worker host instance type** — evaluated against its workload characteristics. Scoring here is not strictly pass/fail — some choices that are technically workable but not the best fit for this workload may receive partial credit.
3. **Network isolation** — VPC/subnet CIDRs, worker has no public IP, both Security Groups correctly scoped.
4. **Live checks** — `GET /healthcheck` on the api host, `GET /check-private` (proves api → worker connectivity), and `GET /check-batch` (proves the worker's actual `/batch-job` endpoint is running and computing correctly), all made from outside your infrastructure against the api host's public IP.

`JUSTIFICATION.md` is graded separately, manually, after autograding.


## Grading Rubric

**Autograded (10 points):**

| Check | Points |
|---|---|
| API host instance type matches its workload characteristics | 2 |
| Worker host instance type matches its workload characteristics (partial credit possible for a reasonable-but-not-optimal choice) | 2 |
| Network isolation correct (CIDRs, no public IP on worker, Security Groups scoped) | 2 |
| Live: api host `/healthcheck` | 2 |
| Live: worker reachable via api's `/check-private` proxy | 1 |
| Live: worker's `/batch-job` computes correctly, verified via api's `/check-batch` proxy | 1 |

**Manually graded (10 points) — `JUSTIFICATION.md`:**

| Criterion | Points |
|---|---|
| Host A: workload reasoning → instance choice | 2 |
| Host A: cost comparison vs. an alternative, with real $ figures | 2 |
| Host B: workload reasoning → instance choice, addressing burstable vs. sustained-load performance considerations | 2 |
| Host B: cost comparison vs. an alternative, including the 24/7-vs-actual-runtime consideration | 2 |
| Clarity and terminology; if AI-assisted, a substantive note on what was specifically verified | 2 |

**Deductions:**

- No credit: wrong region (not `us-west-2`), or using a different AWS account than the one registered in Assignment 1
- No credit: secrets or credentials hardcoded or visible in the repository.
- No credit: any file modified from the "Files Provided Complete — Do Not Modify" list above.
