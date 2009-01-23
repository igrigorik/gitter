require 'rubygems'
require 'open-uri'
require 'date'
require 'json'

class DateTime
  def to_rfc2822
    sprintf("%.3s, %02d %.3s %04d %02d:%02d:%02d %s",
      Date::DAYNAMES[self.wday],
      self.day, Date::MONTHNAMES[self.mon],
      self.year, self.hour, self.min, self.sec,
      self.zone)
  end
end

username = 'igrigorik'
codeswarm_path = '/code/source/code_swarm/'

userdata = JSON.parse(open('http://github.com/api/v1/json/'+username).read)["user"]
puts "Author: #{userdata["name"]}"
puts "Email: #{userdata["email"]}"
puts "Blog: #{userdata["blog"]}" unless userdata["blog"].nil?
puts "Repositories (#{userdata["repositories"].size}):"
puts userdata["repositories"].collect {|r| r["name"] }.join(", ")

puts "\nCollecting commits"
history = File.open("user-history.log", "w")

# Expected format in user_history.log
# ------------------------------------------------------------------------
# r14920d2 (14920d22c70d6ef6bbf9f4f40c173163c8cc7672) | todd.fisher@gmail.com | 2008-11-30 17:30:14 -0500 (Sun, 30 Nov 2008 17:30:14 -0500) | x lines
# Changed paths:
# M ext/extconf.rb
# A tests/bug_curb_easy_blocks_ruby_threads.rb
# D ext/ectconf_old.rb

user_commits = []
userdata["repositories"].each do |repo|

  repodata = JSON.parse(open("http://github.com/api/v1/json/#{username}/#{repo["name"]}/commits/master").read)
  commits = repodata["commits"]

  # Sample commit information from API (JSON):
  # {
  #  "author"=>{"name"=>"Ilya Grigorik", "email"=>"ilya@igvita.com"},
  #  "parents"=>[{"id"=>"5ba52cf1982690b2942b035fa2b33e44331d0c99"}],
  #  "url"=>"http://github.com/igrigorik/oauth-plugin/commit/8c75285fcbf88033dab024cd748d5f49792d2be0",
  #  "id"=>"8c75285fcbf88033dab024cd748d5f49792d2be0",
  #  "committed_date"=>"2008-08-03T01:51:43-07:00",
  #  "authored_date"=>"2008-08-03T01:51:43-07:00",
  #  "message"=>"FIXED: Bug in default ...",
  #  "committer"=>{"name"=>"Ilya Grigorik", "email"=>"ilya@igvita.com"},
  #  "tree"=>"211db4c1de04281c332d9dd2fcdc7b0a981b73f8"
  # }

  commits.each do |commit|
    next if commit["committer"]["email"] != userdata["email"]

    puts "#{repo["name"]}: #{commit["id"]}"
    commitdata = JSON.parse(open("http://github.com/api/v1/json/#{username}/#{repo["name"]}/commit/#{commit["id"]}").read)["commit"]
    
    commit["committed_date"] = DateTime.parse(commit["committed_date"])
    commit["details"] = commitdata

    user_commits.push commit
  end
end

user_commits.sort_by {|c| c["committed_date"]}
user_commits.each do |commit|

  history.write("\n\n------------------------------------------------------------------------\n")
  history.write("r#{commit["id"][0,7]} | #{commit["committer"]["email"]} | ")
  history.write("#{commit["committed_date"].strftime("%Y-%m-%d %H:%M:%S %Z")} ")
  history.write("(#{commit["committed_date"].to_rfc2822}) | ")
  history.write("x lines\n")
  history.write("Changed paths:")

  # Sample commit drilldown from API (JSON):
  # {
  #     {"removed": [{"filename": "commands.rb"}, {"filename": "helpers.rb"}],
  #     "added": [{"filename": "commands/commands.rb"}, {"filename": "commands/helpers.rb"}],
  #     "message": "move commands.rb and helpers.rb into commands/ dir",
  #     "modified": [{"diff": "@@ -56,7 +56,7 @@ ..."}],
  #     "parents": [{"id": "d462d2a2e60438ded3dd9e8e6593ca4146c5a0ba"}],
  #     "url": "http://github.com/defunkt/github-gem/commit/c26d4ce9807ecf57d3f9eefe19ae64e75bcaaa8b",
  #     "author": {"name": "Chris Wanstrath", "email": "chris@ozmm.org"},
  #     "id": "c26d4ce9807ecf57d3f9eefe19ae64e75bcaaa8b",
  #     "committed_date": "2008-03-02T16:45:41-08:00",
  #     "authored_date": "2008-03-02T16:45:41-08:00",
  #     "tree": "28a1a1ca3e663d35ba8bf07d3f1781af71359b76",
  #     "committer": {"name": "Chris Wanstrath", "email": "chris@ozmm.org"}}}
  # }

  %w(added removed modified).each do |action|
    commit["details"][action].each do |file|
      history.write("\n#{action[0,1].capitalize} #{file["filename"]}")
    end
  end
end

# convert git logs to code_swarm XML format (make sure codeswarm/bin is in your path)
`#{codeswarm_path}/bin/convert_logs.py -g user-history.log -o user-history.log.xml`
