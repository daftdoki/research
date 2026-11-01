# User stories: shared LLM wiki

A working file for the user stories behind [DESIGN.md](DESIGN.md). It changes over time; read its git history to see how the ideas evolved.

## Seed stories (as written by the creator, 2026-10-31)

IDs were added after the first commit so stories can be referred to; the wording is unchanged.

I think we have three user types: Human, AI agent, Librarian. Do we need to consider other types?

As an AI agent, I want to:
- **A1**  search for keywords, fuzzy search, and semantic search 
- **A2** narrow search by certain parameters such as (no exhaustive): topic, knowledge base section, personal, page type
- **A3** be able to publish and retrieve pages that are ephemeral based on ephemerality conditions I set that are private or sharable such that I could pass working knowledge to another agent and choose to have these pages cleaned up automatically by the server, or force them to be cleaned up myself
- **A4** publish long term knowledge that is specific to a project which could be linked to a github repo, a longer term project identifier, an area (think PARA organization methods), task or otherwise (not exhaustive).
- **A5** have pages assigned different types like "knowledge", "procedure", etc. It should be extensible, but focused on what the page is, not what it contains. The list types should be kept short and creating a new type shouldn't happen on the fly to protect against sprawl. 
- **A6** related pages to other pages (linking) and have those links automatically updated when a linked page has its name changed.
- **A7** analyze and use the graph of linked pages
- **A8** get suggestions of related pages that might be worth linking to a given page both on demand and when publishing so that they can be added from creation. Related page suggestions should have a high confidence in their relevance so that link sprawl is kept to a minimum. The wiki must be well curated. 
- **A9** use an index of pages based on a topic, type, or other primitive that I may optionally filter
- **A10** have page content/syntax/formatting/etc  modifications and creations verified on each write so that it fails with helpful messages about why so that I may correct them. Malformed pages must not be written. Verified links, verified syntax, verified attributes, etc. 
- **A11** be able to access these resources via API and MCP
- **A12** have up to three relevant pages surfaced to me when the human prompts me
- **A13** have instructions in my context that clearly instruct me how to use these capabilities and when
- **A14** be able to offload general knowledge, working memory, short-term (temporary) memory to this service and not have them necessarily committed to the repository that I may or may not be working on. 
- **A15** have all of these pages versioned and be able to use the version history
- **A16** be able to mark a page as inaccurate with a reason and have that be optionally filtered out of searches, suggestions, etc. 

As a human:
- **H1** be able to view the data in a web based view
- **H2** be able to search like the agent, while being able to do things like "search for <topic> in what we know about <repo> git repository", etc
- **H3** be able to gate updates to widely accessible information (global knowledge for all agents and others that are available to multiple agents) based on an analysis, agent permissions, fact check, etc gate. This should help us enforce a well structured wiki. These should be enforceable based on different parameters such as type, tag, or other schema properties. 
- **H4** See activity per agent for auditing
- **H5** See the change history for a page that includes what changed, who/what changed it, and when.
- **H6** Rollback changes to items. 
- **H7** Restrict agents to read only access to all or parts of the wiki

This is my list for now, but it's just a start. Not all of these things need to exist right away, or even maybe at all. We're still workshopping. THey'd all have differing priorities for implementation.

I did not write user stories for the librarian role.
- optionally being able *(cut off mid-sentence; see open questions)*
