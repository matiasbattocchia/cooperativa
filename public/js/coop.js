//var ac = new usig.AutoCompleter('dirección');

function cambiarBarrio() {

  $( '#barrio' ).empty();

  $.ajax({
    url: '/localidades',
    data: {
      criteria: {
        nivel_1: $( '#provincia' ).val(),
        localidad: $( '#localidad' ).val()
      },
      nivel: 'barrio'
    },
    success: function( data ) {

      $.each(data, function( index, value ) {

        $( '#barrio' ).append( '<option value="' + value + '">' + value + '</option>' );

      });

      if(data.size < 2) {
        
        $( '#barrio' ) 'disabled'
      
      } else {

      }
    }
  });
}

$( '#provincia' ).change(function() {

  $( '#localidad' ).empty();

  $.ajax({
    url: '/localidades',
    data: {
      criteria: {
        nivel_1: $( '#provincia' ).val()
      },
      nivel: 'localidad'
    },
    success: function( data ) {

      $.each( data, function( index, value ) {

        $( '#localidad' ).append( '<option value="' + value + '">' + value + '</option>' );

      });
    
      cambiarBarrio(); 
    
    }
  });
});


$( '#localidad' ).change(

  cambiarBarrio

);


function initialize() {
  $( '.mapa' ).each( function( indice, direccion ) {

    var d = $(direccion)
    var coordenadas = new google.maps.LatLng( d.data('latitud'), d.data('longitud') )

    var opciones = {
      disableDefaultUI: true,
      zoom: 15,
      center: coordenadas
    };

    var map = new google.maps.Map( direccion, opciones );
    
    var marker = new google.maps.Marker({
      position: coordenadas,
      map: map,
      title: d.data('nombre')
    });
  })
}

// function loadScript() {
//   var script = document.createElement('script');
//   script.type = 'text/javascript';
//   script.src = 'https://maps.googleapis.com/maps/api/js?v=3.exp&sensor=false&' +
//     'callback=initialize';
//   document.body.appendChild(script);
// }

// window.onload = loadScript;

$(document).on("click", ".abrir-modalPedido", function () {
  var profesor = $(this).data('profesor');
  var materias = $(this).data('materias');
  var lugar = $(this).data('lugar');
  var día = $(this).data('día');
  var desde = $(this).data('desde');
  var hasta = $(this).data('hasta');
  var horarioAlumno = $(this).data('horario_alumno');
  var horarioProfesor = $(this).data('horario_profesor');
  $("#modalPedido .modal-title").text( "Clase con " + profesor );
  $("#modalPedido #materias").text( materias );
  $("#modalPedido #lugar").text( lugar );
  $("#modalPedido #día").text( día );
  $("#modalPedido #desde").val( desde );
  $("#modalPedido #hasta").val( hasta );
  $("#modalPedido #horarioAlumno").val( horarioAlumno );
  $("#modalPedido #horarioProfesor").val( horarioProfesor );
});
