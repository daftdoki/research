# User stories: shared LLM wiki

A working file for the user stories behind [DESIGN.md](DESIGN.md). It changes over time; read its git history to see how the ideas evolved.

## Seed stories (as written by the creator, 2026-10-31)

I think we have three user types: Human, AI agent, Librarian. Do we need to consider other types?

As an AI agent, I want to:
-  search for keywords, fuzzy search, and semantic search 
- narrow search by certain parameters such as (no exhaustive): topic, knowledge base section, personal, page type
- be able to publish and retrieve pages that are ephemeral based on ephemerality conditions I set that are private or sharable such that I could pass working knowledge to another agent and choose to have these pages cleaned up automatically by the server, or force them to be cleaned up myself
- publish long term knowledge that is specific to a project which could be linked to a github repo, a longer term project identifier, an area (think PARA organization methods), task or otherwise (not exhaustive).
- have pages assigned different types like "knowledge", "procedure", etc. It should be extensible, but focused on what the page is, not what it contains. The list types should be kept short and creating a new type shouldn't happen on the fly to protect against sprawl. 
- related pages to other pages (linking) and have those links automatically updated when a linked page has its name changed.
- analyze and use the graph of linked pages
- get suggestions of related pages that might be worth linking to a given page both on demand and when publishing so that they can be added from creation. Related page suggestions should have a high confidence in their relevance so that link sprawl is kept to a minimum. The wiki must be well curated. 
- use an index of pages based on a topic, type, or other primitive that I may optionally filter
- have page content/syntax/formatting/etc  modifications and creations verified on each write so that it fails with helpful messages about why so that I may correct them. Malformed pages must not be written. Verified links, verified syntax, verified attributes, etc. 
- be able to access these resources via API and MCP
- have up to three relevant pages surfaced to me when the human prompts me
- have instructions in my context that clearly instruct me how to use these capabilities and when
- be able to offload general knowledge, working memory, short-term (temporary) memory to this service and not have them necessarily committed to the repository that I may or may not be working on. 
- have all of these pages versioned and be able to use the version history
- be able to mark a page as inaccurate with a reason and have that be optionally filtered out of searches, suggestions, etc. 

As a human:
- be able to view the data in a web based view
- be able to search like the agent, while being able to do things like "search for <topic> in what we know about <repo> git repository", etc
- be able to gate updates to widely accessible information (global knowledge for all agents and others that are available to multiple agents) based on an analysis, agent permissions, fact check, etc gate. This should help us enforce a well structured wiki. These should be enforceable based on different parameters such as type, tag, or other schema properties. 
- See activity per agent for auditing
- See the change history for a page that includes what changed, who/what changed it, and when.
- Rollback changes to items. 
- Restrict agents to read only access to all or parts of the wiki

This is my list for now, but it's just a start. Not all of these things need to exist right away, or even maybe at all. We're still workshopping. THey'd all have differing priorities for implementation.

I did not write user stories for the librarian role.
- optionally being able
