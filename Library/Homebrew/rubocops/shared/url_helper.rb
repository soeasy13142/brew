# typed: true # rubocop:todo Sorbet/StrictSigil
# frozen_string_literal: true

require "rubocops/shared/helper_functions"

module RuboCop
  module Cop
    # This module performs common checks the `homepage` field in both formulae and casks.
    module UrlHelper
      include HelperFunctions

      # Yields to block when there is a match.
      #
      # @param urls [Array] url/mirror method call nodes
      # @param regex [Regexp] pattern to match URLs
      def audit_urls(urls, regex)
        urls.each_with_index do |url_node, index|
          if @type == :cask
            url_string_node = url_node.first_argument
            url_string = url_node.source
          else
            url_string_node = parameters(url_node).first
            url_string = string_content(url_string_node)
          end

          match_object = regex_match_group(url_string_node, regex)
          next unless match_object

          offending_node(url_string_node.parent)

          yield match_object, url_string, index
        end
      end

      def audit_url(type, urls, mirrors, livecheck_url: false)
        @type = type

        # URLs must be ASCII; IDNs must be punycode
        ascii_pattern = /[^\p{ASCII}]+/
        audit_urls(urls, ascii_pattern) do |_, url|
          problem "Please use the ASCII (Punycode-encoded host, URL-encoded path and query) version of #{url}."
        end

        # GNU URLs; doesn't apply to mirrors
        gnu_pattern = %r{^(?:https?|ftp)://ftpmirror\.gnu\.org/(.*)}
        audit_urls(urls, gnu_pattern) do |match, url|
          problem "#{url} should be: https://ftp.gnu.org/gnu/#{match[1]}"
        end

        # Fossies upstream requests they aren't used as primary URLs
        # https://github.com/Homebrew/homebrew-core/issues/14486#issuecomment-307753234
        fossies_pattern = %r{^https?://fossies\.org/}
        audit_urls(urls, fossies_pattern) do
          problem "Please don't use \"fossies.org\" in the `url` (using as a mirror is fine)"
        end

        apache_pattern = %r{^https?://(?:[^/]*\.)?apache\.org/(?:dyn/closer\.cgi\?path=/?|dist/)(.*)}i
        audit_urls(urls, apache_pattern) do |match, url|
          next if url == livecheck_url

          problem "#{url} should be: https://www.apache.org/dyn/closer.lua?path=#{match[1]}"
        end

        version_control_pattern = %r{^(cvs|bzr|hg|fossil)://}
        audit_urls(urls, version_control_pattern) do |match, _|
          problem "Use of the \"#{match[1]}://\" scheme is deprecated, pass `using: :#{match[1]}` instead"
        end

        svn_pattern = %r{^svn\+http://}
        audit_urls(urls, svn_pattern) do |_, _|
          problem "Use of the \"svn+http://\" scheme is deprecated, pass `using: :svn` instead"
        end

        audit_urls(mirrors, /.*/) do |_, mirror|
          urls.each do |url|
            url_string = string_content(parameters(url).first)
            next unless url_string.eql?(mirror)

            problem "URL should not be duplicated as a mirror: #{url_string}"
          end
        end

        urls += mirrors

        # Check a variety of SSL/TLS URLs that don't consistently auto-redirect
        # or are overly common errors that need to be reduced & fixed over time.
        http_to_https_patterns = Regexp.union([%r{^http://ftp\.gnu\.org/},
                                               %r{^http://ftpmirror\.gnu\.org/},
                                               %r{^http://download\.savannah\.gnu\.org/},
                                               %r{^http://download-mirror\.savannah\.gnu\.org/},
                                               %r{^http://(?:[^/]*\.)?apache\.org/},
                                               %r{^http://code\.google\.com/},
                                               %r{^http://fossies\.org/},
                                               %r{^http://mirrors\.kernel\.org/},
                                               %r{^http://mirrors\.ocf\.berkeley\.edu/},
                                               %r{^http://(?:[^/]*\.)?bintray\.com/},
                                               %r{^http://tools\.ietf\.org/},
                                               %r{^http://launchpad\.net/},
                                               %r{^http://github\.com/},
                                               %r{^http://bitbucket\.org/},
                                               %r{^http://anonscm\.debian\.org/},
                                               %r{^http://cpan\.metacpan\.org/},
                                               %r{^http://hackage\.haskell\.org/},
                                               %r{^http://(?:[^/]*\.)?archive\.org},
                                               %r{^http://(?:[^/]*\.)?freedesktop\.org},
                                               %r{^http://(?:[^/]*\.)?mirrorservice\.org/},
                                               %r{^http://downloads?\.sourceforge\.net/}])
        audit_urls(urls, http_to_https_patterns) do |_, url, index|
          # It's fine to have a plain HTTP mirror further down the mirror list.
          https_url = url.dup.insert(4, "s")
          https_index = T.let(nil, T.nilable(Integer))
          audit_urls(urls, https_url) do |_, _, found_https_index|
            https_index = found_https_index
          end
          problem "Please use https:// for #{url}" if !https_index || https_index > index
        end

        apache_mirror_pattern = %r{^https?://(?:[^/]*\.)?apache\.org/dyn/closer\.(?:cgi|lua)\?path=/?(.*)}i
        audit_urls(mirrors, apache_mirror_pattern) do |match, mirror|
          problem "#{mirror} should be: https://archive.apache.org/dist/#{match[1]}"
        end

        cpan_pattern = %r{^http://search\.mcpan\.org/CPAN/(.*)}i
        audit_urls(urls, cpan_pattern) do |match, url|
          problem "#{url} should be: https://cpan.metacpan.org/#{match[1]}"
        end

        gnome_pattern = %r{^(http|ftp)://ftp\.gnome\.org/pub/gnome/(.*)}i
        audit_urls(urls, gnome_pattern) do |match, url|
          problem "#{url} should be: https://download.gnome.org/#{match[2]}"
        end

        debian_pattern = %r{^git://anonscm\.debian\.org/users/(.*)}i
        audit_urls(urls, debian_pattern) do |match, url|
          problem "#{url} should be: https://anonscm.debian.org/git/users/#{match[1]}"
        end

        # Prefer HTTP/S when possible over FTP protocol due to possible firewalls.
        mirror_service_pattern = %r{^ftp://ftp\.mirrorservice\.org}
        audit_urls(urls, mirror_service_pattern) do |_, url|
          problem "Please use https:// for #{url}"
        end

        cpan_ftp_pattern = %r{^ftp://ftp\.cpan\.org/pub/CPAN(.*)}i
        audit_urls(urls, cpan_ftp_pattern) do |match_obj, url|
          problem "#{url} should be: http://search.cpan.org/CPAN#{match_obj[1]}"
        end

        # SourceForge url patterns
        sourceforge_patterns = %r{^https?://.*\b(sourceforge|sf)\.(com|net)}
        audit_urls(urls, sourceforge_patterns) do |_, url|
          # Skip if the URL looks like a SVN repository.
          next if url.include? "/svnroot/"
          next if url.include? "svn.sourceforge"
          next if url.include? "/p/"

          if url =~ /(\?|&)use_mirror=/
            problem "Don't use \"#{Regexp.last_match(1)}use_mirror\" in SourceForge URLs (`url` is #{url})."
          end

          problem "Don't use \"/download\" in SourceForge URLs (`url` is #{url})." if url.end_with?("/download")

          if url.match?(%r{^https?://(sourceforge|sf)\.}) && url != livecheck_url
            problem "Use \"https://downloads.sourceforge.net\" to get geolocation (`url` is #{url})."
          end

          if url.match?(%r{^https?://prdownloads\.})
            problem "Don't use \"prdownloads\" in SourceForge URLs (`url` is #{url})."
          end

          if url.match?(%r{^http://\w+\.dl\.})
            problem "Don't use specific \"dl\" mirrors in SourceForge URLs (`url` is #{url})."
          end

          # sf.net does HTTPS -> HTTP redirects.
          if url.match?(%r{^https?://downloads?\.sf\.net})
            problem "Use \"https://downloads.sourceforge.net\" instead of \"downloads.sf.net\" (`url` is #{url})"
          end
        end

        # Debian has an abundance of secure mirrors. Let's not pluck the insecure
        # one out of the grab bag.
        unsecure_deb_pattern = %r{^http://http\.debian\.net/debian/(.*)}i
        audit_urls(urls, unsecure_deb_pattern) do |match, _|
          problem <<~EOS
            Please use a secure mirror for Debian URLs.
            We recommend:
              https://deb.debian.org/debian/#{match[1]}
          EOS
        end

        # Check to use canonical URLs for Debian packages
        noncanon_deb_pattern =
          Regexp.union([%r{^https://mirrors\.kernel\.org/debian/},
                        %r{^https://mirrors\.ocf\.berkeley\.edu/debian/},
                        %r{^https://(?:[^/]*\.)?mirrorservice\.org/sites/ftp\.debian\.org/debian/}])
        audit_urls(urls, noncanon_deb_pattern) do |_, url|
          problem "Please use https://deb.debian.org/debian/ for #{url}"
        end

        # Check for new-url Google Code download URLs, https:// is preferred
        google_code_pattern = Regexp.union([%r{^http://[A-Za-z0-9\-.]*\.googlecode\.com/files.*},
                                            %r{^http://code\.google\.com/}])
        audit_urls(urls, google_code_pattern) do |_, url|
          problem "Please use https:// for #{url}"
        end

        # Check for `git://` GitHub repository URLs, https:// is preferred.
        git_gh_pattern = %r{^git://[^/]*github\.com/}
        audit_urls(urls, git_gh_pattern) do |_, url|
          problem "Please use https:// for #{url}"
        end

        # Check for `git://` Gitorious repository URLs, https:// is preferred.
        git_gitorious_pattern = %r{^git://[^/]*gitorious\.org/}
        audit_urls(urls, git_gitorious_pattern) do |_, url|
          problem "Please use https:// for #{url}"
        end

        # Check for `http://` GitHub repository URLs, https:// is preferred.
        gh_pattern = %r{^http://github\.com/.*\.git$}
        audit_urls(urls, gh_pattern) do |_, url|
          problem "Please use https:// for #{url}"
        end

        # Check for default branch GitHub archives.
        if type == :formula
          tarball_gh_pattern = %r{^https://github\.com/.*archive/(main|master)\.(tar\.gz|zip)$}
          audit_urls(urls, tarball_gh_pattern) do
            problem "Use versioned rather than branch tarballs for stable checksums."
          end
        end

        # Use new-style archive downloads.
        archive_gh_pattern = %r{https://.*github.*/(?:tar|zip)ball/}
        audit_urls(urls, archive_gh_pattern) do |_, url|
          next if url.end_with?(".git")

          problem "Use /archive/ URLs for GitHub tarballs (`url` is #{url})."
        end

        archive_refs_gh_pattern = %r{https://.*github.+/archive/(?![a-fA-F0-9]{40})(?!refs/(tags|heads)/)(.*)\.tar\.gz$}
        audit_urls(urls, archive_refs_gh_pattern) do |match, url|
          next if url.end_with?(".git")

          problem %Q(Use "refs/tags/#{match[2]}" or "refs/heads/#{match[2]}" for GitHub references (`url` is #{url}).)
        end

        # Don't use GitHub .zip files
        zip_gh_pattern = %r{https://.*github.*/(archive|releases)/.*\.zip$}
        audit_urls(urls, zip_gh_pattern) do |_, url|
          next if url.match? %r{raw.githubusercontent.com/.*/.*/(main|master|HEAD)/}
          next if url.include?("releases/download")
          next if url.include?("desktop.githubusercontent.com/releases/")

          problem "Use GitHub tarballs rather than zipballs (`url` is #{url})."
        end

        # Don't use GitHub codeload URLs
        codeload_gh_pattern = %r{https?://codeload\.github\.com/(.+)/(.+)/(?:tar\.gz|zip)/(.+)}
        audit_urls(urls, codeload_gh_pattern) do |match, url|
          problem <<~EOS
            Use GitHub archive URLs:
              https://github.com/#{match[1]}/#{match[2]}/archive/#{match[3]}.tar.gz
            Rather than codeload:
              #{url}
          EOS
        end

        # Check for Maven Central URLs, prefer HTTPS redirector over specific host
        maven_pattern = %r{https?://(?:central|repo\d+)\.maven\.org/maven2/(.+)$}
        audit_urls(urls, maven_pattern) do |match, url|
          problem "#{url} should be: https://search.maven.org/remotecontent?filepath=#{match[1]}"
        end
      end
    end
  end
end
