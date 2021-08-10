# Workplace Search Example Connector

> :warning: This connector is a tool to illustrate best-practices for building custom connectors
> for Workplace Search. It has not been tested at scale and has some notable feature gaps (detailed below).
> Nevertheless, it serves as an excellent template on which to base your own connector.

This code is a connector built to show best practices for indexing data into [Workplace Search](https://www.elastic.co/workplace-search/).
It indexes GitLab data to illustrate the concepts involved in building a connector.
The following data types are indexed:
- Projects.
- Issues.
- Merge Requests.

It is written in Ruby, though the concepts are easily translatable to any modern programming language.
Given that the connector is a teaching tool, and not a production-ready connector, you may find some features
missing that you would expect from a comprehensive GitLab connector. Some of these are noted in the TODOs section below.

Note there also exists a [HowTo guide on writing a connector](https://www.elastic.co/guide/en/workplace-search/current/workplace-search-custom-api-sources.html), 
as well as a comprehensive [API reference](https://www.elastic.co/guide/en/workplace-search/current/workplace-search-custom-sources-api.html).

## Requirements

This connector requires:
- Ruby >= 2.5
- Workplace Search >= 7.13.0 and a Platinum+ license.
- GitLab API >= v4

## Bootstrapping

Before indexing can begin, you must Bootstrap a new content source to index against. To do this, run the bootstrap command:
```bash
ruby bootstrap.rb --host <Workplace Search Host> --name <Name of Content Source> --username <Admin Username>
```
The bootstrap command will prompt you for the user's password. 
If you want to pass it in to the command you may use the `--password` argument. Be careful though not to echo your password to a logfile.

After the content source is created, the bootstrapping will print the ID of the content source. You will use this to begin indexing (see below).
If you wish to make further customisations to the Content Source you can do so either via the Admin UI, or using
the [Custom Source API](https://www.elastic.co/guide/en/workplace-search/current/workplace-search-content-sources-api.html#update-content-source-api).

## Indexing

Once you have bootstrapped a Content Source, you can begin indexing into it. 
Each call to indexing uses a time range to limit the amount of data that is pushed at once, and to enable indexing jobs to run concurrently to improve throughput.
To begin indexing a time range, run the following:
```bash
ruby index.rb --host=<Workplace Search Host> \
  --access-token=<Content Source Access Token> \
  --content-source-id=<Content Source ID from Bootstrapping> \
  --gitlab-host="https://gitlab.com/api/v4" \
  --gitlab-token=<Gitlab Access Token> \
  --from=<ISO8601 timestamp> --to=<ISO8601 timestamp>
```

The `Content Source Access Token` can be retrieved from the Details page of the Content Source in the Admin UI.
You can use [this guide](https://docs.gitlab.com/ee/user/profile/personal_access_tokens.html) to create the `Gitlab Access Token`.

## Clean-up

When items are deleted from GitLab, a separate process is required to update Workplace Search accordingly.
This runs in a similar fashion to the indexing script. It does also need, though, a `search-access-token`,
which is used to query the Search API in Workplace Search. Such a token can be retrieved from Workplace Search
using the [OAuth flow](https://www.elastic.co/guide/en/workplace-search/master/workplace-search-api-authentication.html#oauth-token).

```bash
ruby cleanup.rb --host=<WORKPLACE SEARCH HOST> \
  --access-token=<CONTENT SOURCE ACCESS TOKEN> \
  --search-access-token=<OAUTH ACCESS TOKEN> \
  --content-source-id=<CONTENT SOURCE ID> \
  --gitlab-host="https://gitlab.com/api/v4" \
  --gitlab-token=<GITLAB ACCESS TOKEN> \
  --from=<ISO8601 timestamp> --to=<ISO8601 timestamp>
```

## TODOs
Following are some items that have not yet been implemented:
- Comments on Issues are not indexed.
- Comments on Merge Requests are not indexed.
- Access controls set on the Project are not applied, meaning any user can see the indexed content.
