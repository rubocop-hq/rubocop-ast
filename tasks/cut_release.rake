# frozen_string_literal: true

require 'bump'

namespace :cut_release do
  %w[major minor patch pre].each do |release_type|
    desc "Cut a new #{release_type} release, create release notes " \
         'and update documents.'
    task release_type do
      run(release_type)
    end
  end

  def update_file(path)
    content = File.read(path)
    File.write(path, yield(content))
  end

  def add_header_to_changelog(version)
    update_file('CHANGELOG.md') do |changelog|
      head, tail = changelog.split("## master (unreleased)\n\n", 2)
      [
        head,
        "## master (unreleased)\n\n",
        "## #{version} (#{Time.now.strftime('%F')})\n\n",
        tail
      ].join
    end
  end

  def run(release_type)
    old_version = Bump::Bump.current
    Bump::Bump.run(release_type, commit: false, bundle: false, tag: false)
    new_version = Bump::Bump.current

    add_header_to_changelog(new_version)

    puts "Changed version from #{old_version} to #{new_version}."
  end
end
