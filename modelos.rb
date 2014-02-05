require 'mongoid'

Mongoid.load!('mongoid.yml')
Mongoid.raise_not_found_error = false

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
  field :estado, default: 'Habilitado'

  Estados = [
    'Habilitado',
    'Desabilitado'
  ]

  validates_uniqueness_of :correo
  validates_inclusion_of :estado, in: Estados
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
    'En lugar',
    'Desde lugar'
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
