# encoding: utf-8

require 'gooddata'

require_relative '../config'

GoodData.with_connection($CONFIG[:username], $CONFIG[:password], :server => $CONFIG[:server], :verify_ssl => false) do |client|
  timestamp = DateTime.now.strftime('%Y%m%d%H%M%S')

  blueprint = GoodData::Model::ProjectBlueprint.build("LCM Development Project - #{timestamp}") do |p|
    p.add_date_dimension('committed_on')
    p.add_dataset('devs') do |d|
      d.add_anchor('attr.dev')
      d.add_label('label.dev_id', :reference => 'attr.dev')
      d.add_label('label.dev_email', :reference => 'attr.dev')
    end

    p.add_dataset('repos') do |d|
      d.add_anchor('attr.repos_id')
      d.add_label('label.repo_name', :reference => 'attr.repos_id')
    end

    p.add_dataset('commits') do |d|
      d.add_anchor('attr.commits_id')
      d.add_fact('fact.lines_changed')
      d.add_date('committed_on')
      d.add_reference('devs')
      d.add_reference('repos')
    end
  end

  project = GoodData::Project.create_from_blueprint(blueprint, auth_token: $CONFIG[:tokens][:postgres])
  puts JSON.pretty_generate(project.json)

  project.set_metadata('GOODOT_CUSTOM_PROJECT_ID', 'basic')
  project.set_metadata('GD_LCM_TYPE', 'master')
  project.set_metadata('GD_LCM_SEGMENT', 'basic')
  project.set_metadata('GD_LCM_VERSION', '1')

  # Load data
  # commits_data = [
  #   ['fact.lines_changed', 'committed_on', 'devs'],
  #   [1, '01/01/2014', 1],
  #   [3, '01/02/2014', 2],
  #   [5, '05/02/2014', 3]]
  # project.upload(commits_data, blueprint, 'commits')
  #
  # devs_data = [
  #   ['label.dev_id', 'label.dev_email'],
  #   [1, 'tomas@gooddata.com'],
  #   [2, 'petr@gooddata.com'],
  #   [3, 'jirka@gooddata.com']]
  # project.upload(devs_data, blueprint, 'devs')

  # Create a metric
  metric = project.facts('fact.lines_changed').create_metric
  metric.save
  puts JSON.pretty_generate(metric.json)

  # Create report
  report = project.create_report(title: 'Awesome_report', top: [metric], left: ['label.dev_email'])
  report.save
  puts JSON.pretty_generate(report.json)

  # Deploy ETL
  etl_path = File.join(File.dirname(__FILE__), '../etl')
  process = project.deploy_process(etl_path, type: 'GRAPH', name: 'Test ETL Process')
  schedule = process.create_schedule('0 15 27 7 *', 'graph/graph.grf')
  schedule.disable!

  # TODO: Create dashboard
  dashboard = project.create_dashboard(:title => 'Sample Dashboard')

  tab = dashboard.create_tab(:title => 'First Tab')

  item = tab.add_report_item(:report => report, :position_x => 0, :position_y => 20)
  dashboard.save

  puts JSON.pretty_generate(item.json)
end