require 'ci/common'

def mongo_version
  ENV['FLAVOR_VERSION'] || '3.0.1'
end

def mongo_rootdir
  "#{ENV['INTEGRATIONS_DIR']}/mongo_#{mongo_version}"
end

namespace :ci do
  namespace :mongo do |flavor|
    task before_install: ['ci:common:before_install']

    task :install do
      Rake::Task['ci:common:install'].invoke('mongo')
      sh %(bash #{ENV['SDK_HOME']}/mongo/test/ci/start-docker.sh)
    end

    task before_script: ['ci:common:before_script'] do
      # Some of the changes made above will not have propagated.
      # Wait for an arbitrary time to make sure they do
      sleep 10
    end

    task script: ['ci:common:script'] do
      this_provides = [
        'mongo'
      ]
      Rake::Task['ci:common:run_tests'].invoke(this_provides)
    end

    task before_cache: ['ci:common:before_cache']

    # task cleanup: ['ci:common:cleanup']
    # sample cleanup task
    task cleanup: ['ci:common:cleanup'] do
      sh %(bash #{ENV['SDK_HOME']}/mongo/test/ci/stop-docker.sh)
    end

    task :execute do
      exception = nil
      begin
        %w(before_install install before_script).each do |u|
          Rake::Task["#{flavor.scope.path}:#{u}"].invoke
        end
        if !ENV['SKIP_TEST']
          Rake::Task["#{flavor.scope.path}:script"].invoke
        else
          puts 'Skipping tests'.yellow
        end
        Rake::Task["#{flavor.scope.path}:before_cache"].invoke
      rescue => e
        exception = e
        puts "Failed task: #{e.class} #{e.message}".red
      end
      if ENV['SKIP_CLEANUP']
        puts 'Skipping cleanup, disposable environments are great'.yellow
      else
        puts 'Cleaning up'
        Rake::Task["#{flavor.scope.path}:cleanup"].invoke
      end
      raise exception if exception
    end
  end
end
