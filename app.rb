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
  inflect.irregular('provincia', 'provincias')
  inflect.singular('provincia', 'provincia') # ActiveSupport bug.
  inflect.irregular('preferencia', 'preferencias')
  inflect.irregular('usuario', 'usuarios')
  inflect.irregular('materia', 'materias')
  inflect.irregular('horario', 'horarios')
  inflect.irregular('localidad', 'localidades')
  inflect.irregular('dirección', 'direcciones')
  inflect.irregular('lugar', 'lugares')
  inflect.irregular('lugar_precargado', 'lugares_precargados')
  inflect.irregular('lugarprecargado', 'lugaresprecargados')
end


class Usuario
  include Mongoid::Document

  has_many :horarios
  has_many :lugares
  has_and_belongs_to_many :localidades
  has_and_belongs_to_many :materias

  field :nombre
  field :correo
  field :teléfono

  field :rol

  field :clases_a_domicilio?, type: Boolean
  field :clases_en_lugar_público?, type: Boolean
  field :clases_en_domicilio?, type: Boolean

  field :estado, default: 'Deshabilitado'

  # field :institución
  # field :carrera
  # field :sede
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


class Localidad
  include Mongoid::Document

  has_many :lugares
  has_many :lugares_precargados

  field :barrio
  field :comuna
  field :localidad
  field :nivel_2
  field :zona
  field :nivel_1

  def datos
    barrio ? barrio : localidad
  end
end


class Lugar
  include Mongoid::Document

  belongs_to :localidad
  belongs_to :usuario
  has_and_belongs_to_many :zonas, class_name: 'Localidad', inverse_of: nil
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
      if not establecimiento.empty?
        establecimiento
      elsif not (calle.empty? || altura.empty?)
        calle + ' ' + altura
      else
        localidad.barrio || localidad.localidad
      end
  end
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


class LugarPrecargado
  include Mongoid::Document

  belongs_to :localidad

  field :establecimiento
  field :calle
  field :altura
  field :departamento

  field :longitud, type: Float
  field :latitud, type: Float

  field :público?, type: Boolean
end


if Localidad.empty?
  localidades.each do |localidad|
    Localidad.create localidad
  end
end


lugares_precargados = [
  {localidad:
     {nivel_1: 'Ciudad Autónoma de Buenos Aires', localidad: 'Buenos Aires', comuna: '2',  barrio: 'Recoleta'},
   lugar:
     {establecimiento: 'Ciudad Universitaria', calle: nil, altura: nil, departamento: nil, longitud: -58.123, latitud: -38.123, público?: true}
  },
  {localidad:
     {nivel_1: 'Ciudad Autónoma de Buenos Aires', localidad: 'Buenos Aires', comuna: '13', barrio: 'Núñez'},
   lugar:
     {establecimiento: 'Facultad de Ciencias Sociales (UBA)', calle: 'Manso', altura: '123', departamento: nil, longitud: -58.123, latitud: -38.123, público?: true}
  }
]


if LugarPrecargado.empty?
  lugares_precargados.each do |lugar_precargado|
    Localidad.find_by(lugar_precargado[:localidad]).lugares_precargados << LugarPrecargado.new(lugar_precargado[:lugar])
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

  # horarios
  # preferencias de localidad si hay

  # modalidades = []
  # modalidades << {clases_en_domicilio?: true} if @alumno.clases_a_domicilio?
  # modalidades << {clases_a_domicilio?: true} if @alumno.clases_en_domicilio?
  # modalidades << {clases_en_lugar_público?: true} if @alumno.clases_en_lugar_público?

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
    localidad.lugares << lugar = Lugar.new(params[:lugar])

    query = "address=#{lugar.establecimiento},#{lugar.altura} #{lugar.calle},#{localidad.barrio},#{localidad.localidad},#{localidad.nivel_2},#{localidad.nivel_1}&sensor=false".gsub(' ', '+')

    url = 'maps.googleapis.com'
    urn = '/maps/api/geocode/json?' + query

    respuesta = JSON.parse(Net::HTTP.get(url, urn))

    if respuesta['status'] == 'OK'
      coordenadas = respuesta["results"].first["geometry"]["location"]

      lugar.latitud  = coordenadas['lat']
      lugar.longitud = coordenadas['lng']
    end

    @usuario.lugares << lugar
  end

  redirect to "/#{@usuario.correo}/lugares"
end


delete '/:correo/lugares/:lugar' do
  @usuario = Usuario.find_by(correo: params[:correo])

  @usuario.lugares.find_by(nombre: params[:lugar]).delete

  redirect to "/#{@usuario.correo}/lugares"
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


### PREFERENCIAS ###

get '/:correo/preferencias' do
  @usuario = Usuario.find_by(correo: params[:correo])

  slim :preferencias
end


post '/:correo/preferencias' do
  @usuario = Usuario.find_by(correo: params[:correo])

  @usuario.localidades << Localidad.find_by(params[:localidad])

  redirect to "/#{@usuario.correo}/preferencias"
end


delete '/:correo/preferencias/:id' do
  @usuario = Usuario.find_by(correo: params[:correo])
  
  @usuario.localidades.find(params[:id]).delete

  redirect to "/#{@usuario.correo}/preferencias"
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
