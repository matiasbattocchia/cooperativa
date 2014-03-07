require 'bundler/setup'
require 'sinatra'
require 'haversine'
require 'net/http'
require 'rack-flash'
require __dir__ + '/modelos.rb'

set :bind, '0.0.0.0'
set :server, :puma

enable :sessions
use Rack::Flash

Bundler.require(:default, :development)

configure :development do
  use BetterErrors::Middleware
  BetterErrors.application_root = File.expand_path('..', __FILE__)
end


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

  def flash_types
    [:success, :notice, :warning, :error]
  end
end


### Alumnos y Profesores ###

get '/:correo/profesores' do
  @usuario = Usuario.find_by(correo: params[:correo])
  
  @profesores = Usuario.where(rol: 'Profesor')

  slim :lista
end

get '/:correo/alumnos' do
  @usuario = Usuario.find_by(correo: params[:correo])
  
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

# Duración mínima de una clase en minutos.

Duración = 90


### BÚSQUEDA ###

get '/:correo/búsqueda' do
  @alumno = Usuario.find_by(correo: params[:correo], rol: 'Alumno')

  profesores = Usuario.where(rol: 'Profesor', estado: 'Habilitado').in(materia_ids: @alumno.materia_ids)

  @profesores = Hash.new { |h,k| h[k]=[] }
  
  if params[:materias]

    profesores.each do |profesor|
      profesor.horarios.each do |horario_profesor|
        @alumno.horarios.each do |horario_alumno|
          if (día = horario_profesor.día) == horario_alumno.día
            hora_desde =
              horario_profesor.desde.en_minutos <
                horario_alumno.desde.en_minutos ?
                  horario_alumno.desde : horario_profesor.desde
            
            hora_hasta =
              horario_profesor.hasta.en_minutos <
                horario_alumno.hasta.en_minutos ?
                  horario_profesor.hasta : horario_alumno.hasta
            
            if (tiempo = hora_hasta.en_minutos - hora_desde.en_minutos) >= Duración

              distancia = Haversine.distance(
                horario_profesor.lugar.latitud,
                horario_profesor.lugar.longitud,
                horario_alumno.lugar.latitud,
                horario_alumno.lugar.longitud)

              if (horario_profesor.modalidad == 'En lugar' &&
                  horario_alumno.modalidad == 'En lugar' &&
                  horario_profesor.lugar.tipo != 'Domicilio' &&
                  horario_alumno.lugar.tipo != 'Domicilio' &&
                  distancia < 0.01) ||
                  horario_profesor.modalidad != horario_alumno.modalidad
                
                @profesores[profesor.id] << {profesor: profesor, horario_profesor: horario_profesor, horario_alumno: horario_alumno, desde: hora_desde, hasta: hora_hasta, distancia: distancia, tiempo: tiempo}
              end
            end
          end
        end
      end
    end
  end

  slim :búsqueda
end

post '/:correo/b%C3%BAsqueda' do
  @alumno = Usuario.find_by(correo: params[:correo], rol: 'Alumno')
  
  @alumno.update_attributes(params[:fechas])

  redirect to "/#{@alumno.correo}/búsqueda?materias=#{@alumno.materias.map(&:nombre).join(',')}"
end


### LOGIN ###

get '/' do
  slim :index
end


post '/' do
@usuario =
  Usuario.where(correo: params[:correo]).first_or_create

  redirect to "/#{@usuario.correo}/perfil"
end


### DATOS ###

get '/:correo/perfil' do
  @usuario = Usuario.find_by(correo: params[:correo])

  slim :perfil
end


post '/:correo/perfil' do
  @usuario = Usuario.find_by(correo: params[:correo])

  @usuario.update_attributes(params[:datos])

  flash[:message] = 'Guardado.'

  if params[:estado]
    case params[:estado]
    when 'Habilitar' then @usuario.estado = 'Habilitado'
    when 'Deshabilitar' then @usuario.estado = 'Deshabilitado'
    end
    @usuario.save
  else
    redirect to "/#{@usuario.correo}/perfil"
  end
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

  flash[:message] = 'Guardado.'

  redirect to "/#{@usuario.correo}/materias"
end


### LUGARES ###

get '/:correo/lugares' do
  @usuario = Usuario.find_by(correo: params[:correo])

  slim :lugares
end


post '/:correo/lugares' do

  @usuario = Usuario.find_by(correo: params[:correo])

  if params[:lugar_precargado]
    @usuario.lugares << Lugar.where(usuario: nil).find(params[:lugar_precargado_id]).clone
  else
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
      
        lugar.localidad = localidad

        @usuario.lugares << lugar
      end
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

  if (localidad = Localidad.find_by(params[:localidad])) &&
     (lugar = @usuario.lugares.find(params[:lugar_id]))

    zona = Zona.new
    zona.localidad = localidad
    zona.lugar = lugar

    @usuario.zonas << zona
  end

  redirect to "/#{@usuario.correo}/lugares/#{lugar.nombre.gsub(' ', '_')}/zonas"
end


delete '/:correo/zonas/:zona_id' do
  @usuario = Usuario.find_by(correo: params[:correo])
  
  (zona = @usuario.zonas.find(params[:zona_id])).delete

  redirect to "/#{@usuario.correo}/lugares/#{zona.lugar.nombre.gsub(' ', '_')}/zonas"
end


### HORARIOS ###

get '/:correo/lugares/:lugar_nombre/horarios' do
  @usuario = Usuario.find_by(correo: params[:correo])

  @lugar = @usuario.lugares.find_by(nombre: params[:lugar_nombre].gsub('_', ' '))
  
  slim :horarios
end


post '/:correo/horarios' do
  @usuario = Usuario.find_by(correo: params[:correo])
 
  if lugar = @usuario.lugares.find(params[:lugar_id])

    params[:horario][:días].each do |día|
      params[:horario][:modalidades].each do |modalidad|

        horario.lugar = lugar
        horario.día = día
        horario.desde = params[:horario][:desde]
        horario.hasta = params[:horario][:hasta]
        horario.modalidad = modalidad

        @usuario.horarios << horario
      end
    end
  end
  
  redirect to "/#{@usuario.correo}/lugares/#{lugar.nombre.gsub(' ', '_')}/horarios"
end


delete '/:correo/horarios/:horario_id' do
  @usuario = Usuario.find_by(correo: params[:correo])
  
  (horario = @usuario.horarios.find(params[:horario_id])).delete

  redirect to "/#{@usuario.correo}/lugares/#{horario.lugar.nombre.gsub(' ', '_')}/horarios"
end


### Agenda ###

get '/:correo/agenda' do
  @usuario = Usuario.find_by(correo: params[:correo])

  @eventos = @usuario.eventos.where(:desde.gt => Time.now)

  # Horario::Días.each do |día|
  #   @usuario.horarios.where(día: día).each do |horario|
      
      
  #     @segmentos = []  
  #   end
  # end

  slim :agenda
end

post '/:correo/agenda' do
  @usuario = Usuario.find_by(correo: params[:correo])

  evento = Evento.new
  evento.desde = Time.new *params[:evento][:fecha_desde].split('/').reverse, *params[:evento][:hora_desde].split(':')
  evento.hasta = Time.new *params[:evento][:fecha_hasta].split('/').reverse, *params[:evento][:hora_hasta].split(':')
  evento.tipo = 'Otro'

  @usuario.eventos << evento

  redirect to "/#{@usuario.correo}/agenda"
end
