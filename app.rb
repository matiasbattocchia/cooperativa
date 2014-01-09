require 'bundler/setup'

Bundler.require(:default, :development)

Mongoid.load!('mongoid.yml')
Mongoid.raise_not_found_error = false

configure :development do
  use BetterErrors::Middleware
  BetterErrors.application_root = File.expand_path('..', __FILE__)
end

ActiveSupport::Inflector.inflections do |inflect|
  inflect.irregular('usuario', 'usuarios')
  inflect.irregular('materia', 'materias')
  inflect.irregular('horario', 'horarios')
  inflect.irregular('lugar', 'lugares')
end

class Usuario
  include Mongoid::Document
  has_many :horarios
  has_and_belongs_to_many :lugares
  has_and_belongs_to_many :materias
  field :nombre
  field :correo
  field :teléfono
  field :dirección
  field :rol
end

class Materia
  include Mongoid::Document
  has_and_belongs_to_many :usuarios
  field :nombre
end

if Materia.empty?
  ['Matemáticas',
   'Física',
   'Química'].each do |materia|
     Materia.create(nombre: materia)
   end
end

class Horario
  include Mongoid::Document
  belongs_to :usuario
  field :día
  field :desde, type: Time
  field :hasta, type: Time
end

class Lugar
  include Mongoid::Document
  has_and_belongs_to_many :usuarios
  field :nombre
end
  
if Lugar.empty?
  ['Ciudad Universitaria',
   'Casa alumno',
   'Casa profesor',
   'Lugar público'].each do |lugar|
     Lugar.create(nombre: lugar)
   end
end

class Clase
  include Mongoid::Document
  belongs_to :profesor
  belongs_to :usuario
  belongs_to :materia
end

class Pedido
  include Mongoid::Document
  belongs_to :usuario
end

# TODO: Reportar bug Mongoid first_or_create + attr_readonly
# TODO: push() --> concat()
# TODO: Que <<() no agregue nil
# TODO: Completitud de datos antes de avanzar
# TODO: Protección de datos
# TODO: Validación días y horarios

### LOGIN ###

get '/' do
  slim :index
end


post '/' do
  @usuario =
    Usuario.where(correo: params[:correo]).first_or_create

  redirect to "/#{@usuario.correo}/materias"
end


### MATERIAS ###

get '/:correo/materias' do
  @usuario = Usuario.find_by(correo: params[:correo])

  @materias = Materia.all.asc(:nombre)

  slim :materias
end


post '/:correo/materias' do
  @usuario = Usuario.find_by(correo: params[:correo])
  
  @usuario.materias = []

  params[:materias].each do |materia|
    @usuario.materias << Materia.find(materia)
  end

  redirect to "/#{@usuario.correo}/horarios"
end


### HORARIOS ###

get '/:correo/horarios' do
  @usuario = Usuario.find_by(correo: params[:correo])

  slim :horarios
end


post '/:correo/horarios' do
  @usuario = Usuario.find_by(correo: params[:correo])
  
  @usuario.horarios << Horario.new(params[:horario])
  
  redirect to "/#{@usuario.correo}/horarios"
end


delete '/:correo/horarios/:id' do
  @usuario = Usuario.find_by(correo: params[:correo])
  
  @usuario.horarios.find(params[:id]).delete

  redirect to "/#{@usuario.correo}/horarios"
end


### LUGARES ###

get '/:correo/lugares' do
  @usuario = Usuario.find_by(correo: params[:correo])

  @lugares = Lugar.all.asc(:nombre)

  slim :lugares
end


post '/:correo/lugares' do
  @usuario = Usuario.find_by(correo: params[:correo])
  
  @usuario.lugares = []

  params[:lugares].each do |lugar|
    @usuario.lugares << Lugar.find(lugar)
  end

  redirect to "/#{@usuario.correo}/datos"
end


### DATOS ###

get '/:correo/datos' do
  @usuario = Usuario.find_by(correo: params[:correo])

  slim :datos
end


post '/:correo/datos' do
  @usuario = Usuario.find_by(correo: params[:correo])

  @usuario.update_attributes(params[:datos])

  redirect to '/'
end
