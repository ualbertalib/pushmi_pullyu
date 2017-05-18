# Make sure code changes come with corresponding tests
has_app_changes = !git.modified_files.grep(/lib/).empty?
has_spec_changes = !git.modified_files.grep(/spec/).empty?

if has_app_changes && !has_spec_changes
  warn('There are code changes, but no corresponding tests. '\
         'Please include tests if this PR introduces any modifications in '\
         'behavior.',
       sticky: false)
end

# Make it more obvious that a PR is a work in progress and shouldn't be merged yet
warn('PR is classed as Work in Progress') if github.pr_title.include? '[WIP]'

# Mainly to encourage writing up some reasoning about the PR, rather than
# just leaving a title
warn('Please add a detailed summary in the description.') if github.pr_body.length < 5

# Ensure a clean commits history
if git.commits.any? { |c| c.message =~ /^Merge branch '#{github.branch_for_base}'/ }
  warn 'Please rebase to get rid of the merge commits in this PR'
end

# Warn when there is a big PR
warn('This PR is too big! Consider breaking it down into smaller PRs.') if git.lines_of_code > 1000
