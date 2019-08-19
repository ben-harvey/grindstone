require 'sinatra'
require 'tilt/erubis'
require 'sinatra/content_for'

require_relative 'database_persistence'

configure do
  enable :sessions
  set :session_secret, 'secret'
  set :erb, escape_html: true
end

configure(:development) do
  require 'sinatra/reloader'
  also_reload 'database_persistence.rb'
end

before do
  @storage = DatabasePersistence.new(logger)
end

after do
  @storage.disconnect
end

# rubocop:disable Metrics/BlockLength
helpers do
  def list_completed?(list)
    list[:todos_count] > 0 && list[:todos_remaining] == 0
  end

  def todo_completed?(todo)
    todo[:completed]
  end

  def list_class(list)
    'complete' if list_completed?(list)
  end

  def todo_class(todo)
    'complete' if todo_completed?(todo)
  end

  def remaining_to_total(list)
    total = list[:todos_count]
    remaining = list[:todos_remaining]
    "#{remaining} / #{total}"
  end

  def sort_lists(lists)
    complete_lists, incomplete_lists = lists.partition do |list|
      list_completed?(list)
    end

    incomplete_lists.each { |list| yield list, lists.index(list) }
    complete_lists.each { |list| yield list, lists.index(list) }
  end

  def sort_todos(todos)
    complete_todos, incomplete_todos = todos.partition do |todo|
      todo_completed?(todo)
    end

    incomplete_todos.each { |todo| yield todo }
    complete_todos.each { |todo| yield todo }
  end
end

# rubocop:enable Metrics/BlockLength

def load_list(list_id)
  list = @storage.find_list(list_id)
  return list if list

  session[:error] = 'The specified list was not found.'
  redirect '/lists'
end

get '/' do
  redirect '/lists'
end

# view list of lists
get '/lists' do
  @lists = @storage.all_lists
  erb :lists, layout: :layout
end

# render the new list form
get '/lists/new' do
  erb :new_list, layout: :layout
end

# render the edit list form
get '/lists/:id/edit' do
  @id = params[:id].to_i
  @list = load_list(@id)
  erb :edit, layout: :layout
end

# render a list
get '/lists/:id' do
  @list_id = params[:id].to_i
  @list = load_list(@list_id)
  @todos = @storage.find_todos_for_list(@list_id)
  erb :list, layout: :layout
end

# return an error message if name is invalid. return nil if name is valid
def error_for_list_name(name)
  if @storage.all_lists.any? { |list| list[:name] == name }
    'List name must be unique.'
  elsif !(1..100).cover?(name.size)
    'List name must be between 1 and 100 characters.'
  end
end

# return an error message if text is invalid. return nil if text is valid
def error_for_todo(text)
  return if (1..100).cover?(text.size)
  'Todo text must be between 1 and 100 characters.'
end

# delete a list
post '/lists/:id/delete' do
  id = params[:id].to_i
  @storage.delete_list(id)

  if env['HTTP_X_REQUESTED_WITH'] == 'XMLHttpRequest'
    '/lists'
  else
    session[:success] = 'The list has been deleted.'
    redirect '/lists'
  end
end

# delete a todo from a list
post '/lists/:list_id/todos/:todo_id/delete' do
  list_id = params[:list_id].to_i
  todo_id = params[:todo_id].to_i

  @storage.delete_todo(list_id, todo_id)

  if env['HTTP_X_REQUESTED_WITH'] == 'XMLHttpRequest'
    status 204
  else
    session[:success] = 'The todo has been deleted.'
    redirect "/lists/#{list_id}"
  end
end

# create a new list
post '/lists' do
  list_name = params[:list_name].strip

  error = error_for_list_name(list_name)
  if error
    session[:error] = error
    erb :new_list, layout: :layout
  else
    @storage.create_new_list(list_name)

    session[:success] = 'The list has been created.'
    redirect '/lists'
  end
end

# edit a list name
post '/lists/:id' do
  list_name = params[:list_name].strip
  @id = params[:id].to_i
  @list = @storage.find_list(@id)

  error = error_for_list_name(list_name)
  if error
    session[:error] = error
    erb :edit, layout: :layout
  else
    @storage.update_list_name(@id, list_name)

    session[:success] = 'The list has been renamed.'
    redirect "/lists/#{@id}"
  end
end

# add a todo to a list
post '/lists/:list_id/todos' do
  @list_id = params[:list_id].to_i
  @list = load_list(@list_id)
  text = params[:todo].strip

  error = error_for_todo(text)
  if error
    session[:error] = error
    erb :list, layout: :layout
  else
    @storage.create_new_todo(@list_id, text)

    session[:success] = 'The todo has been added.'
    redirect "/lists/#{@list_id}"
  end
end

# update the status of a todo
post '/lists/:list_id/todos/:todo_id' do
  list_id = params[:list_id].to_i
  todo_id = params[:todo_id].to_i
  is_completed = params[:completed] == 'true'

  @storage.update_todo_status(list_id, todo_id, is_completed)

  session[:success] = 'The todo has been updated.'
  redirect "/lists/#{list_id}"
end

# mark all todos in a list as complete
post '/lists/:list_id/complete_all' do
  list_id = params[:list_id].to_i

  @storage.mark_all_todos_complete(list_id)

  session[:success] = 'All todos have been completed.'
  redirect "/lists/#{list_id}"
end
