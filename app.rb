require 'bundler/setup'
require 'sinatra'
require 'net/http'

set :bind, '0.0.0.0'

Bundler.require(:default, :development)

Mongoid.load!('mongoid.yml')
Mongoid.raise_not_found_error = false

configure :development do
  use BetterErrors::Middleware
  BetterErrors.application_root = File.expand_path('..', __FILE__)
end

ActiveSupport::Inflector.inflections do |inflect|
  inflect.irregular('provincia', 'provincias')
  inflect.singular('provincia', 'provincia') # ActiveSupport bug.
  inflect.irregular('preferencia', 'preferencias')
  inflect.irregular('usuario', 'usuarios')
  inflect.irregular('materia', 'materias')
  inflect.irregular('horario', 'horarios')
  inflect.irregular('localidad', 'localidades')
  inflect.irregular('dirección', 'direcciones')
end


class Usuario
  include Mongoid::Document
  
  has_many :horarios
  has_many :direcciones
  has_and_belongs_to_many :preferencias
  has_and_belongs_to_many :materias
  
  field :nombre
  field :correo
  field :teléfono

  field :rol

  field :institución
  field :carrera
  field :sede
end

class Materia
  include Mongoid::Document

  has_and_belongs_to_many :usuarios

  field :nombre
  field :nivel
  field :código
end

materias = [
  {nombre: 'Matemática', nivel: 'Secundario'},
  {nombre: 'Física', nivel: 'Secundario'},
  {nombre: 'Química', nivel: 'Secundario'},
  {nombre: 'Biología', nivel: 'Secundario'},
  {nombre: 'Inglés', nivel: 'Secundario'},
  {nombre: 'Matemática', nivel: 'CBC', código: '51'},
  {nombre: 'Física', nivel: 'CBC', código: '03'},
  {nombre: 'Química', nivel: 'CBC', código: '05'},
  {nombre: 'Álgebra', nivel: 'CBC', código: '27'},
  {nombre: 'Análisis Matemático', nivel: 'CBC', código: '28'},
  {nombre: 'Biología', nivel: 'CBC', código: '08'},
]

if Materia.empty?
  materias.each do |materia|
     Materia.create(materia)
   end
end


class Horario
  include Mongoid::Document
  
  belongs_to :usuario
  belongs_to :dirección_desde, class_name: 'Dirección', inverse_of: nil
  belongs_to :dirección_hasta, class_name: 'Dirección', inverse_of: nil
  
  field :día
  field :desde
  field :hasta
end


class Preferencia
  include Mongoid::Document
  
  has_and_belongs_to_many :usuarios
  
  field :nombre
end

if Preferencia.empty?
  ['Institución',
   'Casa alumno',
   'Casa profesor',
   'Lugar público'].each do |lugar|
     Preferencia.create(nombre: lugar)
   end
end

class Localidad
  include Mongoid::Document

  has_many :direcciones

  field :barrio
  field :comuna
  field :localidad
  field :nivel_2
  field :zona
  field :nivel_1
end

class Dirección
  include Mongoid::Document

  belongs_to :localidad
  belongs_to :usuario

  field :calle
  field :altura
  field :adicional

  field :longitud, type: Float
  field :latitud, type: Float
  field :estado
end

localidades = [
  {nivel_1: 'Ciudad Autónoma de Buenos Aires', localidad: 'Buenos Aires', comuna: '15', barrio: 'Agronomía'},
  {nivel_1: 'Ciudad Autónoma de Buenos Aires', localidad: 'Buenos Aires', comuna: '5',  barrio: 'Almagro'},
  {nivel_1: 'Ciudad Autónoma de Buenos Aires', localidad: 'Buenos Aires', comuna: '3',  barrio: 'Balvanera'},
  {nivel_1: 'Ciudad Autónoma de Buenos Aires', localidad: 'Buenos Aires', comuna: '4',  barrio: 'Barracas'},
  {nivel_1: 'Ciudad Autónoma de Buenos Aires', localidad: 'Buenos Aires', comuna: '13', barrio: 'Belgrano'},
  {nivel_1: 'Ciudad Autónoma de Buenos Aires', localidad: 'Buenos Aires', comuna: '5',  barrio: 'Boedo'},
  {nivel_1: 'Ciudad Autónoma de Buenos Aires', localidad: 'Buenos Aires', comuna: '6',  barrio: 'Caballito'},
  {nivel_1: 'Ciudad Autónoma de Buenos Aires', localidad: 'Buenos Aires', comuna: '15', barrio: 'Chacarita'},
  {nivel_1: 'Ciudad Autónoma de Buenos Aires', localidad: 'Buenos Aires', comuna: '12', barrio: 'Coghlan'},
  {nivel_1: 'Ciudad Autónoma de Buenos Aires', localidad: 'Buenos Aires', comuna: '13', barrio: 'Colegiales'},
  {nivel_1: 'Ciudad Autónoma de Buenos Aires', localidad: 'Buenos Aires', comuna: '1',  barrio: 'Constitución'},
  {nivel_1: 'Ciudad Autónoma de Buenos Aires', localidad: 'Buenos Aires', comuna: '7',  barrio: 'Flores'},
  {nivel_1: 'Ciudad Autónoma de Buenos Aires', localidad: 'Buenos Aires', comuna: '10', barrio: 'Floresta'},
  {nivel_1: 'Ciudad Autónoma de Buenos Aires', localidad: 'Buenos Aires', comuna: '4',  barrio: 'La Boca'},
  {nivel_1: 'Ciudad Autónoma de Buenos Aires', localidad: 'Buenos Aires', comuna: '15', barrio: 'La Paternal'},
  {nivel_1: 'Ciudad Autónoma de Buenos Aires', localidad: 'Buenos Aires', comuna: '9',  barrio: 'Liniers'},
  {nivel_1: 'Ciudad Autónoma de Buenos Aires', localidad: 'Buenos Aires', comuna: '9',  barrio: 'Mataderos'},
  {nivel_1: 'Ciudad Autónoma de Buenos Aires', localidad: 'Buenos Aires', comuna: '10', barrio: 'Monte Castro'},
  {nivel_1: 'Ciudad Autónoma de Buenos Aires', localidad: 'Buenos Aires', comuna: '1',  barrio: 'Monserrat'},
  {nivel_1: 'Ciudad Autónoma de Buenos Aires', localidad: 'Buenos Aires', comuna: '4',  barrio: 'Nueva Pompeya'},
  {nivel_1: 'Ciudad Autónoma de Buenos Aires', localidad: 'Buenos Aires', comuna: '13', barrio: 'Núñez'},
  {nivel_1: 'Ciudad Autónoma de Buenos Aires', localidad: 'Buenos Aires', comuna: '14', barrio: 'Palermo'},
  {nivel_1: 'Ciudad Autónoma de Buenos Aires', localidad: 'Buenos Aires', comuna: '9',  barrio: 'Parque Avellaneda'},
  {nivel_1: 'Ciudad Autónoma de Buenos Aires', localidad: 'Buenos Aires', comuna: '7',  barrio: 'Parque Chacabuco'},
  {nivel_1: 'Ciudad Autónoma de Buenos Aires', localidad: 'Buenos Aires', comuna: '15', barrio: 'Parque Chas'},
  {nivel_1: 'Ciudad Autónoma de Buenos Aires', localidad: 'Buenos Aires', comuna: '4',  barrio: 'Parque Patricios'},
  {nivel_1: 'Ciudad Autónoma de Buenos Aires', localidad: 'Buenos Aires', comuna: '1',  barrio: 'Puerto Madero'},
  {nivel_1: 'Ciudad Autónoma de Buenos Aires', localidad: 'Buenos Aires', comuna: '2',  barrio: 'Recoleta'},
  {nivel_1: 'Ciudad Autónoma de Buenos Aires', localidad: 'Buenos Aires', comuna: '1',  barrio: 'Retiro'},
  {nivel_1: 'Ciudad Autónoma de Buenos Aires', localidad: 'Buenos Aires', comuna: '12', barrio: 'Saavedra'},
  {nivel_1: 'Ciudad Autónoma de Buenos Aires', localidad: 'Buenos Aires', comuna: '3',  barrio: 'San Cristóbal'},
  {nivel_1: 'Ciudad Autónoma de Buenos Aires', localidad: 'Buenos Aires', comuna: '1',  barrio: 'San Nicolás'},
  {nivel_1: 'Ciudad Autónoma de Buenos Aires', localidad: 'Buenos Aires', comuna: '1',  barrio: 'San Telmo'},
  {nivel_1: 'Ciudad Autónoma de Buenos Aires', localidad: 'Buenos Aires', comuna: '10', barrio: 'Vélez Sársfield'},
  {nivel_1: 'Ciudad Autónoma de Buenos Aires', localidad: 'Buenos Aires', comuna: '10', barrio: 'Versalles'},
  {nivel_1: 'Ciudad Autónoma de Buenos Aires', localidad: 'Buenos Aires', comuna: '15', barrio: 'Villa Crespo'},
  {nivel_1: 'Ciudad Autónoma de Buenos Aires', localidad: 'Buenos Aires', comuna: '11', barrio: 'Villa del Parque'},
  {nivel_1: 'Ciudad Autónoma de Buenos Aires', localidad: 'Buenos Aires', comuna: '11', barrio: 'Villa Devoto'},
  {nivel_1: 'Ciudad Autónoma de Buenos Aires', localidad: 'Buenos Aires', comuna: '11', barrio: 'Villa General Mitre'},
  {nivel_1: 'Ciudad Autónoma de Buenos Aires', localidad: 'Buenos Aires', comuna: '8',  barrio: 'Villa Lugano'},
  {nivel_1: 'Ciudad Autónoma de Buenos Aires', localidad: 'Buenos Aires', comuna: '10', barrio: 'Villa Luro'},
  {nivel_1: 'Ciudad Autónoma de Buenos Aires', localidad: 'Buenos Aires', comuna: '15', barrio: 'Villa Ortúzar'},
  {nivel_1: 'Ciudad Autónoma de Buenos Aires', localidad: 'Buenos Aires', comuna: '12', barrio: 'Villa Pueyrredón'},
  {nivel_1: 'Ciudad Autónoma de Buenos Aires', localidad: 'Buenos Aires', comuna: '10', barrio: 'Villa Real'},
  {nivel_1: 'Ciudad Autónoma de Buenos Aires', localidad: 'Buenos Aires', comuna: '8',  barrio: 'Villa Riachuelo'},
  {nivel_1: 'Ciudad Autónoma de Buenos Aires', localidad: 'Buenos Aires', comuna: '11', barrio: 'Villa Santa Rita'},
  {nivel_1: 'Ciudad Autónoma de Buenos Aires', localidad: 'Buenos Aires', comuna: '8',  barrio: 'Villa Soldati'},
  {nivel_1: 'Ciudad Autónoma de Buenos Aires', localidad: 'Buenos Aires', comuna: '12', barrio: 'Villa Urquiza'},
  {nivel_1: 'Buenos Aires', zona: 'Norte', nivel_2: 'Vicente López', localidad: 'Vicente López', barrio: 'Carapachay'},
  {nivel_1: 'Buenos Aires', zona: 'Norte', nivel_2: 'Vicente López', localidad: 'Vicente López', barrio: 'Florida'},
  {nivel_1: 'Buenos Aires', zona: 'Norte', nivel_2: 'Vicente López', localidad: 'Vicente López', barrio: 'Florida Oeste'},
  {nivel_1: 'Buenos Aires', zona: 'Norte', nivel_2: 'Vicente López', localidad: 'Vicente López', barrio: 'La Lucila'},
  {nivel_1: 'Buenos Aires', zona: 'Norte', nivel_2: 'Vicente López', localidad: 'Vicente López', barrio: 'Munro'},
  {nivel_1: 'Buenos Aires', zona: 'Norte', nivel_2: 'Vicente López', localidad: 'Vicente López', barrio: 'Olivos'},
  {nivel_1: 'Buenos Aires', zona: 'Norte', nivel_2: 'Vicente López', localidad: 'Vicente López', barrio: 'Vicente López'},
  {nivel_1: 'Buenos Aires', zona: 'Norte', nivel_2: 'Vicente López', localidad: 'Vicente López', barrio: 'Villa Adelina'},
  {nivel_1: 'Buenos Aires', zona: 'Norte', nivel_2: 'Vicente López', localidad: 'Vicente López', barrio: 'Villa Martelli'},
  {nivel_1: 'Buenos Aires', zona: 'Norte', nivel_2: 'San Isidro', localidad: 'Villa Adelina'},
  {nivel_1: 'Buenos Aires', zona: 'Norte', nivel_2: 'San Isidro', localidad: 'Boulogne'},
  {nivel_1: 'Buenos Aires', zona: 'Norte', nivel_2: 'San Isidro', localidad: 'Martínez'},
  {nivel_1: 'Buenos Aires', zona: 'Norte', nivel_2: 'San Isidro', localidad: 'Acassuso'},
  {nivel_1: 'Buenos Aires', zona: 'Norte', nivel_2: 'San Isidro', localidad: 'San Isidro'},
  {nivel_1: 'Buenos Aires', zona: 'Norte', nivel_2: 'San Isidro', localidad: 'Béccar'},
]

if Localidad.empty?
  localidades.each do |localidad|
    Localidad.create localidad
  end
end

# class Clase
#   include Mongoid::Document
#   belongs_to :profesor
#   belongs_to :usuario
#   belongs_to :materia
# end

# class Pedido
#   include Mongoid::Document
#   belongs_to :usuario
# end


# TODO: Reportar bug Mongoid first_or_create + attr_readonly
# TODO: push() --> concat()
# TODO: Que <<() no agregue nil
# TODO: Completitud de datos antes de avanzar
# TODO: No renderizar la página si con el correo no encuentra a la persona
# TODO: Protección de datos
# TODO: Validación días y horarios
# TODO: Dos .change() se referían a la misma función y uno bloqueaba al otro.


get '/localidades' do
  content_type :json
  Localidad.where(params[:criteria]).distinct(params[:nivel]).sort.to_json
end


helpers do
  def google_maps_api
    api_key = 'AIzaSyB7Wm2barF4o6ck5_ki1YzY7SIDX6iK_JM'
    
    "https://maps.googleapis.com/maps/api/js?key=#{api_key}&sensor=false&language=es&callback=initialize"
  end
end


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

  redirect to "/#{@usuario.correo}/lugares"
end


### DIRECCIONES ###

get '/:correo/lugares' do
  @usuario = Usuario.find_by(correo: params[:correo])

  slim :direcciones
end


post '/:correo/lugares' do
  @usuario = Usuario.find_by(correo: params[:correo])

  if localidad = Localidad.find_by(params[:localidad])
    localidad.direcciones << dirección = Dirección.new(params[:dirección])

    query = "address=#{dirección.altura} #{dirección.calle},#{localidad.localidad},#{localidad.nivel_2 + ',' if localidad.nivel_2}#{localidad.nivel_1}&sensor=false".gsub(' ', '+')

    url = 'maps.googleapis.com'
    urn = '/maps/api/geocode/json?' + query

    respuesta = JSON.parse(Net::HTTP.get(url, urn))

    if respuesta['status'] == 'OK'
      coordenadas = respuesta["results"].first["geometry"]["location"]

      dirección.latitud  = coordenadas['lat']
      dirección.longitud = coordenadas['lng']
    end

    dirección.estado = respuesta['status']

    @usuario.direcciones << dirección
  end

  redirect to "/#{@usuario.correo}/lugares"
end


delete '/:correo/lugares/:id' do
  @usuario = Usuario.find_by(correo: params[:correo])

  @usuario.direcciones.find(params[:id]).delete

  redirect to "/#{@usuario.correo}/lugares"
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
  @localidades = Localidad.all.asc(:nombre)

  slim :lugares
end


post '/:correo/lugares' do
  @usuario = Usuario.find_by(correo: params[:correo])
  
  @usuario.lugares = []

  params[:lugares].each do |lugar|
    @usuario.lugares << Lugar.find(lugar)
  end
  
  params[:localidades].each do |localidad|
    @usuario.localidades << Localidad.find(localidad)
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
