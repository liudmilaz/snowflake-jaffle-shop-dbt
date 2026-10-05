# jaffle_shop

dbt Labs' [jaffle_shop tutorial project](https://docs.getdbt.com/guides/snowflake), built against a Snowflake trial account. Started from the standard dbt project scaffold (equivalent to `dbt init`), migrated here from a dbt Cloud managed repository so the same codebase can be developed from both dbt Cloud (Studio IDE) and dbt Core (VS Code).

## Getting started

```
dbt deps
dbt run
dbt test
```

Requires a `jaffle_shop` profile in `~/.dbt/profiles.yml` pointing at the Snowflake trial account (see [dbt's Snowflake setup docs](https://docs.getdbt.com/docs/core/connect-data-platform/snowflake-setup)).

## Licence

MIT — © 2026 Liudmila Zolotukhina. See [LICENSE](LICENSE).

Use it, copy it, change it, teach from it. The only requirement is that the copyright notice travels with copies.
