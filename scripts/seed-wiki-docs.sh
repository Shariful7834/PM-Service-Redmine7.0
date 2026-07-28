#!/usr/bin/env bash
# Seed the installation documentation into Redmine itself.
#
# Christian's requirement (2026-07-28) is that the installation and the plugin
# security ledger are documented *inside* Redmine. Keeping the source of those
# pages in docs/wiki/ and importing them here means the documentation is version
# controlled AND present on every instance, including a fresh server deployment.
#
# Idempotent: re-running updates the pages in place.
#
# Usage: ./scripts/seed-wiki-docs.sh
set -euo pipefail
cd "$(dirname "$0")/.."

# shellcheck disable=SC1091
set -a; . ./.env; set +a

echo "Copying wiki sources into the container..."
docker compose cp docs/wiki redmine:/tmp/wiki >/dev/null

# `docker compose exec` bypasses the entrypoint, so SECRET_KEY_BASE must be passed.
docker compose exec -T \
  -e SECRET_KEY_BASE="${REDMINE_SECRET_KEY_BASE}" \
  redmine bundle exec rails runner '
identifier = "redmine-admin"
project = Project.find_by(identifier: identifier)
unless project
  project = Project.new(
    name: "Redmine Administration",
    identifier: identifier,
    description: "Installation, configuration and plugin governance for the DEE Redmine service.",
    is_public: false
  )
  project.save!
end

# make sure the wiki module is on
names = project.enabled_module_names.map(&:to_s)
project.enabled_module_names = (names + ["wiki"]).uniq
# a project created before load_default_data has no trackers, which breaks
# issue creation with HTTP 500 — attach whatever trackers exist
project.trackers = Tracker.all if project.trackers.empty? && Tracker.any?
project.save!

wiki = project.wiki || Wiki.create!(project: project, start_page: "Home")
author = User.where(admin: true).order(:id).first || User.anonymous

# Home first so child pages can attach to it
files = Dir["/tmp/wiki/*.md"].sort_by { |f| File.basename(f) == "Home.md" ? 0 : 1 }
files.each do |file|
  title = File.basename(file, ".md")
  body  = File.read(file)

  page = wiki.find_page(title) || WikiPage.new(wiki: wiki, title: title)
  page.parent = wiki.find_page("Home") if title != "Home" && wiki.find_page("Home")
  page.save!

  # Save the content explicitly. Relying on page.save! to cascade is unreliable:
  # when the page record itself is unchanged the new text is silently not written,
  # which leaves stale documentation behind while still reporting success.
  content = page.content || WikiContent.new(page: page)
  content.text = body
  content.author = author
  content.save! if content.changed? || content.new_record?

  page.reload
  stored = page.content.text.to_s.gsub("\r\n", "\n").strip
  if stored != body.gsub("\r\n", "\n").strip
    raise "wiki page #{title} did not store the expected content"
  end
  puts "  seeded: #{title} (v#{page.content.version})"
end

puts "OK wiki pages: #{wiki.pages.count} in project \"#{project.name}\""
' RAILS_ENV=production

echo
echo "Documentation seeded. View it at:"
echo "  http://localhost:${REDMINE_PORT}/projects/redmine-admin/wiki"
echo "(project is private — sign in as an administrator)"
