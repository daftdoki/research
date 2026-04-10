Start by creating a new folder for your work with an appropriate name.

Create a notes.md file in that folder and append notes to it as you work, tracking what you tried and anything you learned along the way.

Build a README.md report at the end of the investigation.

## README report format

Your README.md should follow this general structure:

1. **Title** (`# ...`): A clear, descriptive title for the investigation.
2. **Question / Goal**: State what you set out to investigate or build. Frame it so a reader immediately understands the purpose. Include a link to the [Original Prompt](#original-prompt) section at the bottom.
3. **Answer / Summary**: Lead with the conclusion. Give the short answer up front before the details. End with: "For additional and more detailed information see the [research notes](notes.md)."
4. **Methodology / Experiment**: Describe what you did — the setup, tools used, steps taken. Include code blocks, commands, or tables where they help.
5. **Results**: Present what you found — data, output, observations. Use tables for comparative data.
6. **Analysis** (if applicable): Interpret the results. Explain why things worked or didn't, trade-offs, caveats.
7. **Files**: List the files in the project folder and what each one does.
8. **Original Prompt**: The verbatim text of the user's original prompt, quoted in a blockquote (`>`). This should always be the last section of the README.

Adapt this structure to fit the investigation. A benchmark needs detailed results tables. A proof-of-concept needs setup instructions. A bug investigation needs reproduction steps. Use your judgment — the structure should serve the content, not the other way around.

See the `_example/` folder in this repo for a reference project showing the expected format.

## What to commit

Your final commit should include just that folder and selected items from its contents:

- The notes.md and README.md files
- Any code you wrote along the way
- If you checked out and modified an existing repo, the output of "git diff" against that modified repo saved as a file - but not a copy of the full repo
- If appropriate, any binary files you created along the way provided they are less than 2MB in size

Do NOT include full copies of code that you fetched as part of your investigation. Your final commit should include only new files you created or diffs showing changes you made to existing code.

Don't create a _summary.md file - these are added automatically after you commit your changes.
