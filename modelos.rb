require 'mongoid'
require 'tod/time_of_day'

Mongoid.load!('mongoid.yml')
Mongoid.raise_not_found_error = false

ActiveSupport::Inflector.inflections do |inflect|
  inflect.irregular('usuario', 'usuarios')
  inflect.irregular('materia', 'materias')
  inflect.irregular('localidad', 'localidades')
  inflect.irregular('lugar', 'lugares')
  inflect.irregular('zona', 'zonas')
  inflect.irregular('horario', 'horarios')
  inflect.irregular('evento', 'eventos')
end


class Usuario
  include Mongoid::Document

  has_and_belongs_to_many :materias
  has_many :lugares, dependent: :destroy
  has_many :zonas
  has_many :horarios
  has_many :eventos, dependent: :destroy

  field :nombre
  field :correo
  field :teléfono

  field :rol
  field :estado, default: 'Habilitado'

  field :búsqueda_desde, type: Time
  field :búsqueda_hasta, type: Time


  def búsqueda_desde
    fecha = read_attribute(:búsqueda_desde)

    fecha = if fecha
              fecha > Time.now ? fecha : Time.now
            else
              Time.now
            end

    fecha.strftime('%d/%m/%Y')
  end

  def búsqueda_desde=(fecha)
    write_attribute(:búsqueda_desde, Time.new(*fecha.split('/').reverse))
  end

  def búsqueda_hasta
    fecha = read_attribute(:búsqueda_hasta)

    fecha = if fecha
              fecha > Time.now ? fecha : Time.now
            else
              Time.now
            end

    fecha.strftime('%d/%m/%Y')
  end
  
  def búsqueda_hasta=(fecha)
    write_attribute(:búsqueda_hasta, Time.new(*fecha.split('/').reverse))
  end


  Roles = [
    'Alumno',
    'Profesor'
  ]

  Estados = [
    'Habilitado',
    'Desabilitado'
  ]

  validates_uniqueness_of :correo
  validates_inclusion_of :rol, in: Roles, allow_nil: true
  validates_inclusion_of :estado, in: Estados
end


class Materia
  include Mongoid::Document

  # has_and_belongs_to_many :usuarios

  field :nombre
  field :nivel
  field :código
end


class Localidad
  include Mongoid::Document

  has_many :lugares, dependent: :restrict
  has_many :zonas, dependent: :restrict

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
  has_many :zonas, dependent: :destroy
  has_many :horarios, dependent: :destroy

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
    'Comercio',
    'Institución'
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

  field :nombre

  before_create :generar_nombre

  def generar_nombre
    self.nombre = localidad.nombre
  end
end


class Horario
  include Mongoid::Document

  belongs_to :usuario
  belongs_to :lugar

  field :día
  field :desde, type: TimeOfDay
  field :hasta, type: TimeOfDay

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
    'En lugar',
    'Desde lugar'
  ]

  validates_inclusion_of :día, in: Días
  validates_inclusion_of :modalidad, in: Modalidades
end


class Evento
  include Mongoid::Document

  belongs_to :usuario

  field :desde, type: Time
  field :hasta, type: Time
  field :tipo

  Tipos = [
    'Clase',
    'Otro'
  ]

  validates_inclusion_of :tipo, in: Tipos
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
