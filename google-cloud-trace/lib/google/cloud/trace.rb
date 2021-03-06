# Copyright 2016 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.


require "google-cloud-trace"
require "google/cloud/trace/version"
require "google/cloud/trace/credentials"
require "google/cloud/trace/label_key"
require "google/cloud/trace/middleware"
require "google/cloud/trace/notifications"
require "google/cloud/trace/project"
require "google/cloud/trace/result_set"
require "google/cloud/trace/service"
require "google/cloud/trace/span"
require "google/cloud/trace/span_kind"
require "google/cloud/trace/time_sampler"
require "google/cloud/trace/trace_record"
require "google/cloud/trace/utils"
require "google/cloud/config"
require "google/cloud/env"
require "stackdriver/core"

module Google
  module Cloud
    ##
    # # Trace
    #
    # The Stackdriver Trace service collects and stores latency data from your
    # application and displays it in the Google Cloud Platform Console, giving
    # you detailed near-real-time insight into application performance.
    #
    # The Stackdriver Trace Ruby library, `google-cloud-trace`, provides:
    #
    # *   Easy-to-use trace instrumentation that collects and collates latency
    #     data for your Ruby application. If you just want latency trace data
    #     for your application to appear on the Google Cloud Platform Console,
    #     see the section on [instrumenting your app](#instrumenting-your-app).
    # *   An idiomatic Ruby API for querying, analyzing, and manipulating trace
    #     data in your Ruby application. For an introduction to the Trace API,
    #     see the section on the [Trace API](#stackdriver-trace-api).
    #
    # ## Instrumenting Your App
    #
    # This library integrates with Rack-based web frameworks such as Ruby On
    # Rails to provide latency trace reports for your application.
    # Specifcally, it:
    #
    # *   Provides a Rack middleware that automatically reports latency traces
    #     for http requests handled by your application, and measures the
    #     latency of each request as a whole.
    # *   Integrates with `ActiveSupport::Notifications` to add important
    #     latency-affecting events such as ActiveRecord queries to the trace.
    # *   Provides a simple API for your application code to define and
    #     measure latency-affecting processes specific to your application.
    #
    # When this library is installed and configured in your running
    # application, you can view your application's latency traces in real time
    # by opening the Google Cloud Console in your web browser and navigating
    # to the "Trace" section. It also integrates with Google App Engine
    # Flexible and Google Container Engine to provide additional information
    # for applications hosted in those environments.
    #
    # Note that not all requests will have traces. By default, the library will
    # sample about one trace every ten seconds per Ruby process, to prevent
    # heavily used applications from reporting too much data. It will also
    # omit certain requests used by Google App Engine for health checking. See
    # {Google::Cloud::Trace::TimeSampler} for more details.
    #
    # ### Using instrumentation with Ruby on Rails
    #
    # To install application instrumentation in your Ruby on Rails app, add
    # this gem, `google-cloud-trace`, to your Gemfile and update your bundle.
    # Then add the following line to your `config/application.rb` file:
    #
    # ```ruby
    # require "google/cloud/trace/rails"
    # ```
    #
    # This will install a Railtie that automatically integrates with the
    # Rails framework, installing the middleware and the ActiveSupport
    # integration for you. Your application traces, including basic request
    # tracing, ActiveRecord query measurements, and view render measurements,
    # should then start appearing in the Cloud Console.
    #
    # See the {Google::Cloud::Trace::Railtie} class for more information,
    # including how to customize your application traces.
    #
    # ### Using instrumentation with Sinatra
    #
    # To install application instrumentation in your Sinatra app, add this gem,
    # `google-cloud-trace`, to your Gemfile and update your bundle. Then add
    # the following lines to your main application Ruby file:
    #
    # ```ruby
    # require "google/cloud/trace"
    # use Google::Cloud::Trace::Middleware
    # ```
    #
    # This will install the trace middleware in your application, providing
    # basic request tracing for your application. You may measure additional
    # processes such as database queries or calls to external services using
    # other classes in this library. See the {Google::Cloud::Trace::Middleware}
    # documentation for more information.
    #
    # ### Using instrumentation with other Rack-based frameworks
    #
    # To install application instrumentation in an app using another Rack-based
    # web framework, add this gem, `google-cloud-trace`, to your Gemfile and
    # update your bundle. Then add install the trace middleware in your
    # middleware stack. In most cases, this means adding these lines to your
    # `config.ru` Rack configuration file:
    #
    # ```ruby
    # require "google/cloud/trace"
    # use Google::Cloud::Trace::Middleware
    # ```
    #
    # Some web frameworks have an alternate mechanism for modifying the
    # middleware stack. Consult your web framework's documentation for more
    # information.
    #
    # ### The Stackdriver diagnostics suite
    #
    # The trace library is part of the Stackdriver diagnostics suite, which
    # also includes error reporting and log analysis. If you include the
    # `stackdriver` gem in your Gemfile, this trace library will be included
    # automatically. In addition, if you include the `stackdriver` gem in an
    # application using Ruby On Rails, the Railtie will be installed
    # automatically; you will not need to write any code to view latency
    # traces for your appl. See the documentation for the "stackdriver" gem
    # for more details.
    #
    # ## Stackdriver Trace API
    #
    # This library also includes an easy to use Ruby client for the
    # Stackdriver Trace API. This API provides calls to report and modify
    # application traces, as well as to query and analyze existing traces.
    #
    # For further information on the trace API, see
    # {Google::Cloud::Trace::Project}.
    #
    # ### Querying traces using the API
    #
    # Using the Stackdriver Trace API, your application can query and analyze
    # its own traces and traces of other projects. Here is an example query
    # for all traces in the past hour.
    #
    # ```ruby
    # require "google/cloud/trace"
    # trace_client = Google::Cloud::Trace.new
    #
    # traces = trace_client.list_traces Time.now - 3600, Time.now
    # traces.each do |trace|
    #   puts "Retrieved trace ID: #{trace.trace_id}"
    # end
    # ```
    #
    # Each trace is an object of type {Google::Cloud::Trace::TraceRecord},
    # which provides methods for analyzing tasks that took place during the
    # request trace. See https://cloud.google.com/trace for more information
    # on the kind of data you can capture in a trace.
    #
    # ### Reporting traces using the API
    #
    # Usually it is easiest to use this library's trace instrumentation
    # features to collect and record application trace information. However,
    # you may also use the trace API to update this data. Here is an example:
    #
    # ```ruby
    # require "google/cloud/trace"
    #
    # trace_client = Google::Cloud::Trace.new
    #
    # trace = Google::Cloud::Trace.new
    # trace.in_span "root_span" do
    #   # Do stuff...
    # end
    #
    # trace_client.patch_traces trace
    # ```
    #
    # ## Enabling Logging
    #
    # To enable logging for this library, set the logger for the underlying
    # [gRPC](https://github.com/grpc/grpc/tree/master/src/ruby) library. The
    # logger that you set may be a Ruby stdlib
    # [`Logger`](https://ruby-doc.org/stdlib-2.5.0/libdoc/logger/rdoc/Logger.html)
    # as shown below, or a
    # [`Google::Cloud::Logging::Logger`](https://googlecloudplatform.github.io/google-cloud-ruby/#/docs/google-cloud-logging/latest/google/cloud/logging/logger)
    # that will write logs to [Stackdriver
    # Logging](https://cloud.google.com/logging/). See
    # [grpc/logconfig.rb](https://github.com/grpc/grpc/blob/master/src/ruby/lib/grpc/logconfig.rb)
    # and the gRPC
    # [spec_helper.rb](https://github.com/grpc/grpc/blob/master/src/ruby/spec/spec_helper.rb)
    # for additional information.
    #
    # Configuring a Ruby stdlib logger:
    #
    # ```ruby
    # require "logger"
    #
    # module MyLogger
    #   LOGGER = Logger.new $stderr, level: Logger::WARN
    #   def logger
    #     LOGGER
    #   end
    # end
    #
    # # Define a gRPC module-level logger method before grpc/logconfig.rb loads.
    # module GRPC
    #   extend MyLogger
    # end
    # ```
    #
    module Trace
      THREAD_KEY = :__stackdriver_trace_span__

      ##
      # Creates a new object for connecting to the Stackdriver Trace service.
      # Each call creates a new connection.
      #
      # For more information on connecting to Google Cloud see the
      # [Authentication
      # Guide](https://googlecloudplatform.github.io/google-cloud-ruby/#/docs/guides/authentication).
      #
      # @param [String] project_id Project identifier for the Stackdriver Trace
      #   service you are connecting to. If not present, the default project for
      #   the credentials is used.
      # @param [String, Hash, Google::Auth::Credentials] credentials The path to
      #   the keyfile as a String, the contents of the keyfile as a Hash, or a
      #   Google::Auth::Credentials object. (See {Trace::Credentials})
      # @param [String, Array<String>] scope The OAuth 2.0 scopes controlling
      #   the set of resources and operations that the connection can access.
      #   See [Using OAuth 2.0 to Access Google
      #   APIs](https://developers.google.com/identity/protocols/OAuth2).
      #
      #   The default scope is:
      #
      #   * `https://www.googleapis.com/auth/cloud-platform`
      #
      # @param [Integer] timeout Default timeout to use in requests. Optional.
      # @param [String] project Alias for the `project_id` argument. Deprecated.
      # @param [String] keyfile Alias for the `credentials` argument.
      #   Deprecated.
      #
      # @return [Google::Cloud::Trace::Project]
      #
      # @example
      #   require "google/cloud/trace"
      #
      #   trace_client = Google::Cloud::Trace.new
      #
      #   traces = trace_client.list_traces Time.now - 3600, Time.now
      #   traces.each do |trace|
      #     puts "Retrieved trace ID: #{trace.trace_id}"
      #   end
      #
      def self.new project_id: nil, credentials: nil, scope: nil, timeout: nil,
                   client_config: nil, project: nil, keyfile: nil
        project_id ||= (project || default_project_id)
        project_id = project_id.to_s # Always cast to a string
        raise ArgumentError, "project_id is missing" if project_id.empty?

        scope ||= configure.scope
        timeout ||= configure.timeout
        client_config ||= configure.client_config

        credentials ||= (keyfile || default_credentials(scope: scope))
        unless credentials.is_a? Google::Auth::Credentials
          credentials = Trace::Credentials.new credentials, scope: scope
        end

        Trace::Project.new(
          Trace::Service.new(
            project_id, credentials, timeout: timeout,
                                     client_config: client_config
          )
        )
      end

      ##
      # Configure the Stackdriver Trace instrumentation Middleware.
      #
      # The following Stackdriver Trace configuration parameters are
      # supported:
      #
      # * `project_id` - (String) Project identifier for the Stackdriver
      #   Trace service you are connecting to. (The parameter `project` is
      #   considered deprecated, but may also be used.)
      # * `credentials` - (String, Hash, Google::Auth::Credentials) The path to
      #   the keyfile as a String, the contents of the keyfile as a Hash, or a
      #   Google::Auth::Credentials object. (See {Trace::Credentials}) (The
      #   parameter `keyfile` is considered deprecated, but may also be used.)
      # * `scope` - (String, Array<String>) The OAuth 2.0 scopes controlling
      #   the set of resources and operations that the connection can access.
      # * `timeout` - (Integer) Default timeout to use in requests.
      # * `client_config` - (Hash) A hash of values to override the default
      #   behavior of the API client.
      # * `capture_stack` - (Boolean) Whether to capture stack traces for each
      #   span. Default: `false`
      # * `sampler` - (Proc) A sampler Proc makes the decision whether to record
      #   a trace for each request. Default: `Google::Cloud::Trace::TimeSampler`
      # * `span_id_generator` - (Proc) A generator Proc that generates the name
      #   String for new TraceRecord. Default: `random numbers`
      # * `notifications` - (Array) An array of ActiveSupport notification types
      #   to include in traces. Rails-only option. Default:
      #   `Google::Cloud::Trace::Railtie::DEFAULT_NOTIFICATIONS`
      # * `max_data_length` - (Integer) The maximum length of span properties
      #   recorded with ActiveSupport notification events. Rails-only option.
      #   Default:
      #   `Google::Cloud::Trace::Notifications::DEFAULT_MAX_DATA_LENGTH`
      #
      # See the [Configuration
      # Guide](https://googlecloudplatform.github.io/google-cloud-ruby/#/docs/stackdriver/guides/instrumentation_configuration)
      # for full configuration parameters.
      #
      # @return [Google::Cloud::Config] The configuration object
      #   the Google::Cloud::Trace module uses.
      #
      def self.configure
        yield Google::Cloud.configure.trace if block_given?

        Google::Cloud.configure.trace
      end

      ##
      # @private Default project.
      def self.default_project_id
        Google::Cloud.configure.trace.project_id ||
          Google::Cloud.configure.project_id ||
          Google::Cloud.env.project_id
      end

      ##
      # @private Default credentials.
      def self.default_credentials scope: nil
        Google::Cloud.configure.trace.credentials ||
          Google::Cloud.configure.credentials ||
          Trace::Credentials.default(scope: scope)
      end

      ##
      # Set the current trace span being measured for the current thread, or
      # the current trace if no span is currently open. This may be used with
      # web frameworks that assign a thread to each request, to track the
      # trace instrumentation state for the request being handled. You may use
      # {Google::Cloud::Trace.get} to retrieve the data.
      #
      # @param [Google::Cloud::Trace::TraceSpan,
      #     Google::Cloud::Trace::TraceRecord, nil] trace The current span
      #     being measured, the current trace object, or `nil` if none.
      #
      # @example
      #   require "google/cloud/trace"
      #
      #   trace_client = Google::Cloud::Trace.new
      #   trace = trace_client.new_trace
      #   Google::Cloud::Trace.set trace
      #
      #   # Later...
      #   Google::Cloud::Trace.get.create_span "my_span"
      #
      def self.set trace
        trace_context = trace ? trace.trace_context : nil
        Stackdriver::Core::TraceContext.set trace_context
        Thread.current[THREAD_KEY] = trace
      end

      ##
      # Retrieve the current trace span or trace object for the current thread.
      # This data should previously have been set using
      # {Google::Cloud::Trace.set}.
      #
      # @return [Google::Cloud::Trace::TraceSpan,
      #     Google::Cloud::Trace::TraceRecord, nil] The span or trace object,
      #     or `nil`.
      #
      # @example
      #   require "google/cloud/trace"
      #
      #   trace_client = Google::Cloud::Trace.new
      #   trace = trace_client.new_trace
      #   Google::Cloud::Trace.set trace
      #
      #   # Later...
      #   Google::Cloud::Trace.get.create_span "my_span"
      #
      def self.get
        Thread.current[THREAD_KEY]
      end

      ##
      # Open a new span for the current thread, instrumenting the given block.
      # The span is created within the current thread's trace context as set by
      # {Google::Cloud::Trace.set}. The context is updated so any further calls
      # within the block will create subspans. The new span is also yielded to
      # the block.
      #
      # Does nothing if there is no trace context for the current thread.
      #
      # @param [String] name Name of the span to create
      # @param [Google::Cloud::Trace::SpanKind] kind Kind of span to create.
      #     Optional.
      # @param [Hash{String => String}] labels Labels for the span
      #
      # @example
      #   require "google/cloud/trace"
      #
      #   trace_client = Google::Cloud::Trace.new
      #   trace = trace_client.new_trace
      #   Google::Cloud::Trace.set trace
      #
      #   Google::Cloud::Trace.in_span "my_span" do |span|
      #     span.labels["foo"] = "bar"
      #     # Do stuff...
      #
      #     Google::Cloud::Trace.in_span "my_subspan" do |subspan|
      #       subspan.labels["foo"] = "sub-bar"
      #       # Do other stuff...
      #     end
      #   end
      #
      def self.in_span name, kind: Google::Cloud::Trace::SpanKind::UNSPECIFIED,
                       labels: {}
        parent = get
        if parent
          parent.in_span name, kind: kind, labels: labels do |child|
            set child
            begin
              yield child
            ensure
              set parent
            end
          end
        else
          yield nil
        end
      end
    end
  end
end
