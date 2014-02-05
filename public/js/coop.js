//var ac = new usig.AutoCompleter('dirección');

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
    }
  });


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
    }
  });
});


$( '#localidad' ).change(
function() {

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
    }
  });
});


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

$(document).on("click", ".open-AddBookDialog", function () {
  var myBookId = $(this).data('id');
  $(".modal-body #bookId").val( myBookId );
});
