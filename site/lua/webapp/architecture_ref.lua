-- Section index for the Architecture page: how fibrous works internally, stage
-- by stage. Each section's prose lives as a markdown file under docs/ (edited by
-- humans as real markdown) and is rendered by ui.markdown; this table just gives
-- the side-nav order and points each section at its file.

return {
	{ id = "overview", name = "Overview", md = "architecture/overview.md" },
	{ id = "reactive-core", name = "Reactive core", md = "architecture/reactive-core.md" },
	{ id = "commit-pipeline", name = "Commit pipeline", md = "architecture/commit-pipeline.md" },
	{ id = "layout", name = "Layout", md = "architecture/layout.md" },
	{ id = "targets-subwindows", name = "Subwindows", md = "architecture/targets-subwindows.md" },
	{ id = "mount-lifecycle", name = "Mount & resize", md = "architecture/mount-lifecycle.md" },
	{ id = "interaction", name = "The cursor", md = "architecture/interaction.md" },
	{ id = "interactions", name = "Trigger graph", md = "architecture/interactions.md" },
}
