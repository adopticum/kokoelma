# supabase directory

The supabase directory of this repo contains Infrastructure As Code (IaC) that can set up the Supabase backend for this project. The purpose is to have a deterministic repeatable definition and a highly automated workflow.


## Seeding
> No production data is copied to your Preview branch. This is meant to protect your sensitive production data.
>
> You can seed your Preview Branch with sample data using the `seed.sql` file in your Supabase directory. See the Seeding docs for more information.
>
> Data changes in your seed files are not merged to production.


## Branching

### [Multi Environment Branching & Management #36344](https://github.com/orgs/supabase/discussions/36344)

#### Q:
Beeing new to Supabase, it is unclear how to organize the supabase projects/github connections. 
Here is an example of a desired pattern:

Production Database -- persistent database attached to the "main" branch of GitHub repository.
Release Database -- ephemeral database cut from "release/x.x.x" branch of GitHub repository.
Staging Database -- persistent database attached to the "develop" branch of GitHub repository.
PR Database -- ephemeral database attached to a "feat/xyz" branch of GitHub repository.

#### A:
As of June 2025 ephemeral Supabase branches are tied to a PR rather than a git branch. 
To achieve the setup above, you would want to:

- Set your Supabase project as the Production Database (use main as the git branch when you enable branching).
- Create a new persistent Supabase branch (e.g. "staging") and assign it to "develop" git branch.
- PR databases will be created when you open a PR against develop.
- Release databases will be created when you open a PR against main.

