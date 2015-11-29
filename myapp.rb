# myapp.rb
require 'sinatra'
require 'sequel'
require 'bcrypt'
require 'warden'
require 'sinatra/flash'

class SinatraWardenExample < Sinatra::Base
  register Sinatra::Flash

  enable :sessions
  set :session_secret, "supersecret"

  use Warden::Manager do |config|
    # Tell Warden how to save our User info into a session.
    # Sessions can only take strings, not Ruby code, we'll store
    # the User's `id`
    config.serialize_into_session{|user| user.id }
    # Now tell Warden how to take what we've stored in the session
    # and get a User from that information.
    config.serialize_from_session{|id| User.first(id: id) }

    config.scope_defaults :default,
      # "strategies" is an array of named methods with which to
      # attempt authentication. We have to define this later.
      strategies: [:password],
      # The action is a route to send the user to when
      # warden.authenticate! returns a false answer. We'll show
      # this route below.
      action: 'auth/unauthenticated'
    # When a user tries to log in and cannot, this specifies the
    # app to send the user to.
    p 'asdasdasdasdasdasd'
    p self
    config.failure_app = self
  end

  Warden::Manager.before_failure do |env,opts|
    env['REQUEST_METHOD'] = 'POST'
  end

  Warden::Strategies.add(:password) do
    def valid?
      params['user']['email'] && params['user']['password']
    end

    def authenticate!
      user = User.first(email: params['user']['email'])

      if user.nil?
        fail!("The email you entered does not exist.")
      elsif user.authenticate(params['user']['password'])
        success!(user)
      else
        fail!("Could not log in")
      end
    end
  end


  DB = Sequel.connect('sqlite://sinatra_test.db')

  class Post < Sequel::Model
    plugin :timestamps
    many_to_one :user
  end

  class User < Sequel::Model
    one_to_many :posts
    include BCrypt

    def password
      @password ||= Password.new(password_hash)
    end

    def password=(new_password)
      @password = Password.create(new_password)
      self.password_hash = @password
    end

    def authenticate(attempted_password)
      self.password == attempted_password ? true : false
    end
  end


  DB.create_table! :posts do
    primary_key :id
    String :title
    Text :body
    foreign_key :user_id
    DateTime :created_at
    DateTime :updated_at
  end

  DB.create_table! :users do
    primary_key :id
    String :email
    String :password_hash
    DateTime :created_at
    DateTime :updated_at
  end

  # Populate the table
  User.create(:email => 'aaa@example.com', :password => 'qwerty123')
  Post.create(:title => 'abc', :body => 'asdasdasdadasdasd', user_id: User.first.id)
  Post.create(:title => 'def', :body => 'asdasdasdadasdasd')
  Post.create(:title => 'ghi', :body => 'asdasdasdadasdasd')


  helpers do
    def current_user
      env['warden'].user
    end
  end

  get '/' do
    haml :index
  end

  get '/posts' do
    if current_user.nil?
      session[:return_to] = '/posts'
      redirect '/auth/login'
    else
      haml :posts
    end
  end

  get '/posts/:id' do
    post = Post[params[:id]]
    haml :post, locals: {post: post}
  end

  post '/posts/:id/destroy' do
    post = Post[params[:id]]
    post.destroy
    redirect to('/posts')
  end

  get '/auth/login' do
    haml :login
  end

  post '/auth/login' do
    env['warden'].authenticate!

    flash[:success] = "Successfully logged in"

    if session[:return_to].nil?
      redirect '/'
    else
      redirect session[:return_to]
    end
  end

  get '/auth/logout' do
    env['warden'].raw_session.inspect
    env['warden'].logout
    flash[:success] = 'Successfully logged out'
    redirect '/'
  end

  post '/auth/unauthenticated' do
    # session[:return_to] = env['warden.options'][:attempted_path]
    flash[:error] = "You must log in"
    redirect '/auth/login'
  end
end

SinatraWardenExample.run!