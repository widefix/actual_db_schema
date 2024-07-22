document.addEventListener('DOMContentLoaded', function () {
  const migrationActions = document.querySelectorAll('.migration-action');

  migrationActions.forEach(button => {
    button.addEventListener('click', function (event) {
      const originalText = button.value;
      button.value = 'Loading...';
      disableButtons();

      const csrfToken = document.querySelector('meta[name="csrf-token"]').getAttribute('content');

      fetch(event.target.form.action, { 
        method: 'POST', 
        headers: { 
          'X-Requested-With': 'XMLHttpRequest',
          'X-CSRF-Token': csrfToken 
        }
      })
      .then(response => {
        if (response.ok) {
          window.location.reload();
        } else {
          throw new Error('Network response was not ok.');
        }
      })
      .catch(error => {
        console.error('There has been a problem with your fetch operation:', error);
        enableButtons();
        button.value = originalText;
      });

      event.preventDefault();
    });
  });

  function disableButtons() {
    migrationActions.forEach(button => {
      button.disabled = true;
    });
  }

  function enableButtons() {
    migrationActions.forEach(button => {
      button.disabled = false;
    });
  }
});
