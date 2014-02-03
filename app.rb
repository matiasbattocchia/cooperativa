require 'bundler/setup'
require 'sinatra'
require 'haversine'
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
  inflect.irregular('usuario', 'usuarios')
  inflect.irregular('materia', 'materias')
  inflect.irregular('localidad', 'localidades')
  inflect.irregular('lugar', 'lugares')
  inflect.irregular('zona', 'zonas')
  inflect.irregular('horario', 'horarios')
end


class Usuario
  include Mongoid::Document

  has_and_belongs_to_many :materias
  has_many :lugares
  has_many :zonas
  has_many :horarios

  field :nombre
  field :correo
  field :teléfono

  field :rol
  field :estado, default: 'Deshabilitado'
end


class Materia
  include Mongoid::Document

  has_and_belongs_to_many :usuarios

  field :nombre
  field :nivel
  field :código
end


class Localidad
  include Mongoid::Document

  has_many :lugares
  has_many :lugares_precargados
  has_many :zonas

  field :barrio
  field :comuna
  field :localidad
  field :nivel_2
  field :zona
  field :nivel_1

  def nombre
    barrio ? barrio : localidad
  end
end


class Lugar
  include Mongoid::Document

  belongs_to :usuario
  belongs_to :localidad
  has_many :zonas
  has_many :horarios

  field :establecimiento
  field :calle
  field :altura
  field :timbre

  field :tipo
  field :nombre

  field :longitud, type: Float
  field :latitud, type: Float

  Tipos = [
    'Domicilio',
    'Café',
    'Facultad',
    'Biblioteca'
  ]

  validates_inclusion_of :tipo, in: Tipos
  
  before_create :generar_nombre
  
  def generar_nombre
    self.nombre =
      if establecimiento
        establecimiento
      elsif calle && altura
        calle + ' ' + altura
      else
        localidad.nombre
      end
  end
end


class Zona
  include Mongoid::Document
  
  belongs_to :usuario
  belongs_to :localidad
  belongs_to :lugar
end


class Horario
  include Mongoid::Document
  
  belongs_to :usuario
  belongs_to :lugar
  
  field :día
  field :desde
  field :hasta

  field :modalidad

  Días = [
    'Lunes',
    'Martes',
    'Miércoles',
    'Jueves',
    'Viernes',
    'Sábado',
    'Domingo'
  ]

  Modalidades = [
    'En domicilio',
    'A domicilio'
  ]

  validates_inclusion_of :día, in: Días
  validates_inclusion_of :modalidad, in: Modalidades
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
# TODO: Unión de segmentos horarios que se solapan.
# TODO: Client-side geocoding.
# TODO: JS: Dos .change() se referían a la misma función y uno bloqueaba al otro.


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


### Alumnos y Profesores ###

get '/profesores' do
  @profesores = Usuario.where(rol: 'Profesor')

  slim :lista
end

get '/alumnos' do
  @profesores = Usuario.where(rol: 'Alumno')

  slim :lista
end

class String
  def en_minutos
    horas, minutos = self.split(':')
    horas.to_i * 60 + minutos.to_i
  end
end

class Integer
  def en_horas
    (self / 60).to_s + ':' + (self % 60).to_s
  end
end

get '/:correo/búsqueda' do
  @alumno = Usuario.find_by(correo: params[:correo])

  @profesores = Usuario.where(rol: 'Profesor', estado: 'Habilitado', clases_a_domicilio?: true).in(materia_ids: @alumno.materia_ids)

  @profes = Hash.new { |h,k| h[k]=[] }

  @profesores.each do |profesor|
    profesor.horarios.each do |horario_profesor|
      @alumno.horarios.each do |horario_alumno|
        if (día = horario_profesor.día) == horario_alumno.día
          hora_desde =
            horario_profesor.hora_desde.en_minutos <=
              horario_alumno.hora_desde.en_minutos ?
                horario_alumno.hora_desde : horario_profesor.hora_desde
          
          hora_hasta =
            horario_profesor.hora_hasta.en_minutos <=
              horario_alumno.hora_hasta.en_minutos ?
                horario_profesor.hora_hasta : horario_alumno.hora_hasta
          
          if (tiempo = hora_hasta.en_minutos - hora_desde.en_minutos) >= '1:30'.en_minutos
            
            pld = horario_profesor.lugar_desde
            plh = horario_profesor.lugar_hasta

            ald = horario_alumno.lugar_desde
            alh = horario_alumno.lugar_hasta

            distancia = Haversine.distance(pld.latitud, pld.longitud, ald.latitud, ald.longitud)


            @profes[profesor.id] << {día: día, desde: hora_desde, hasta: hora_hasta, horario_profesor: horario_profesor.id, horario_alumno: horario_alumno.id, distancia: distancia, tiempo: tiempo}
        
          end
        end
      end
    end
  end

  slim :búsqueda, layout: false
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


### LUGARES ###

get '/:correo/lugares' do
  @usuario = Usuario.find_by(correo: params[:correo])

  slim :lugares
end


post '/:correo/lugares' do

  @usuario = Usuario.find_by(correo: params[:correo])

  if localidad = Localidad.find_by(params[:localidad])
    lugar = Lugar.new(
      params[:lugar].delete_if { |atributo, valor|
        valor.empty? })

    query = "address=#{lugar.establecimiento},#{lugar.altura} #{lugar.calle},#{localidad.barrio},#{localidad.localidad},#{localidad.nivel_2},#{localidad.nivel_1}&sensor=false".gsub(' ', '+')

    url = 'maps.googleapis.com'
    urn = '/maps/api/geocode/json?' + query

    respuesta = JSON.parse(Net::HTTP.get(url, urn))

    if respuesta['status'] == 'OK'
      coordenadas = respuesta["results"].first["geometry"]["location"]

      lugar.latitud  = coordenadas['lat']
      lugar.longitud = coordenadas['lng']
    
      localidad.lugares << lugar
      @usuario.lugares << lugar
    end
  end

  redirect to "/#{@usuario.correo}/lugares"
end


delete '/:correo/lugares/:lugar_id' do
  @usuario = Usuario.find_by(correo: params[:correo])

  @usuario.lugares.find(params[:lugar_id]).delete

  redirect to "/#{@usuario.correo}/lugares"
end


### ZONAS ###

get '/:correo/lugares/:lugar_nombre/zonas' do
  @usuario = Usuario.find_by(correo: params[:correo])

  @lugar = @usuario.lugares.find_by(nombre: params[:lugar_nombre].gsub('_', ' '))

  slim :zonas
end


post '/:correo/zonas' do
  @usuario = Usuario.find_by(correo: params[:correo])

  @usuario.zonas << Localidad.find_by(params[:localidad])

  redirect to "/#{@usuario.correo}/lugares/#{params[:lugar]}/zonas"
end


delete '/:correo/zonas/:zona_id' do
  @usuario = Usuario.find_by(correo: params[:correo])
  
  @usuario.zonas.find(params[:zona_id]).delete

  redirect to "/#{@usuario.correo}/lugares/#{params[:lugar]}/zonas"
end


### HORARIOS ###

get '/:correo/lugares/:lugar/horarios' do
  @usuario = Usuario.find_by(correo: params[:correo])

  @lugar = @usuario.lugares.find_by(nombre: params[:lugar].gsub('_', ' '))
  
  @horarios = @lugar.horarios

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


### DATOS ###

get '/:correo/datos' do
  @usuario = Usuario.find_by(correo: params[:correo])

  slim :datos
end


post '/:correo/datos' do
  @usuario = Usuario.find_by(correo: params[:correo])

  @usuario.update_attributes(params[:datos])

  if params[:estado]
    case params[:estado]
    when 'Habilitar' then @usuario.estado = 'Habilitado'
    when 'Deshabilitar' then @usuario.estado = 'Deshabilitado'
    end
    @usuario.save
    redirect to "/#{@usuario.correo}/datos"
  else
    redirect to '/'
  end
end
