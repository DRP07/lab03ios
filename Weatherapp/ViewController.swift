import UIKit
import CoreLocation

class ViewController: UIViewController {

    @IBOutlet weak var searchField: UITextField!
    @IBOutlet weak var locationBtn: UIButton!
    @IBOutlet weak var searchBtn: UIButton!
    @IBOutlet weak var locationLabel: UILabel!
    @IBOutlet weak var temperatureLabel: UILabel!
    @IBOutlet weak var weatherConditionLabel: UILabel!
    @IBOutlet weak var weatherIcon: UIImageView!
    @IBOutlet weak var unitSwitch: UISwitch!

    let locationManager = CLLocationManager()
    var isCelsius = true
    var currentTemp: WeatherResponse.currentTemp?
    var activityIndicator: UIActivityIndicatorView?

    override func viewDidLoad() {
        super.viewDidLoad()

        locationManager.delegate = self
        locationManager.requestWhenInUseAuthorization()

        searchField.delegate = self
        searchField.placeholder = "Enter location"

        searchBtn.addTarget(self, action: #selector(searchTemp), for: .touchUpInside)
        locationBtn.addTarget(self, action: #selector(getCurrentLocWeather), for: .touchUpInside)
        unitSwitch.addTarget(self, action: #selector(toggleTempUnit), for: .valueChanged)
    }

    @objc func searchTemp() {
        guard let location = searchField.text, !location.isEmpty else {
            showAlert(message: "Please enter a location")
            return
        }
        fetchWeather(for: location)
    }

    @objc func getCurrentLocWeather() {
        locationManager.startUpdatingLocation()
    }

    @objc func toggleTempUnit() {
        isCelsius.toggle()
        updateTemperatureUnit()
    }

    func showAlert(message: String) {
        let alert = UIAlertController(title: "Error", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    func showLoading(_ loading: Bool) {
        if loading {
            activityIndicator = UIActivityIndicatorView(style: .large)
            activityIndicator?.center = view.center
            activityIndicator?.startAnimating()
            view.addSubview(activityIndicator!)
            searchBtn.isEnabled = false
            locationBtn.isEnabled = false
        } else {
            activityIndicator?.stopAnimating()
            activityIndicator?.removeFromSuperview()
            searchBtn.isEnabled = true
            locationBtn.isEnabled = true
        }
    }

    func updateTemperatureUnit() {
        guard let currentTemp = currentTemp else { return }
        temperatureLabel.text = isCelsius
            ? String(format: "%.1f °F", currentTemp.tempFahrenheit)
            : String(format: "%.1f °C", currentTemp.tempCelsius)
            
    }

    func fetchWeather(for location: String) {
        showLoading(true)
        let apiKey = "7929acf4e0534f1caa122441240411"
        let urlString = "https://api.weatherapi.com/v1/current.json?key=\(apiKey)&q=\(location)&aqi=no"
        
        guard let url = URL(string: urlString) else {
            showAlert(message: "Invalid URL")
            showLoading(false)
            return
        }

        let task = URLSession.shared.dataTask(with: url) { data, response, error in
            DispatchQueue.main.async { self.showLoading(false) }
            if error != nil {
                DispatchQueue.main.async { self.showAlert(message: "Could not fetch weather data. Please try again.") }
                return
            }
            
            guard let data = data else { return }
            do {
                let weatherResponse = try JSONDecoder().decode(WeatherResponse.self, from: data)
                DispatchQueue.main.async { self.updateUI(with: weatherResponse) }
            } catch {
                DispatchQueue.main.async { self.showAlert(message: "Failed to get weather data.") }
            }
        }
        task.resume()
    }

    func fetchWeatherForCurrentLocation(latitude: Double, longitude: Double) {
        showLoading(true)
        let apiKey = "7929acf4e0534f1caa122441240411"
        let urlString = "https://api.weatherapi.com/v1/current.json?key=\(apiKey)&q=\(latitude),\(longitude)&aqi=no"
        
        guard let url = URL(string: urlString) else {
            showAlert(message: "Invalid URL")
            showLoading(false)
            return
        }

        let task = URLSession.shared.dataTask(with: url) { data, response, error in
            DispatchQueue.main.async { self.showLoading(false) }
            if error != nil {
                DispatchQueue.main.async { self.showAlert(message: "Please try again. Could not fetch weather data. ") }
                return
            }
            
            guard let data = data else { return }
            do {
                let weatherResponse = try JSONDecoder().decode(WeatherResponse.self, from: data)
                DispatchQueue.main.async { self.updateUI(with: weatherResponse) }
            } catch {
                DispatchQueue.main.async { self.showAlert(message: "Failed to get weather data.") }
            }
        }
        task.resume()
    }

    func updateUI(with weatherResponse: WeatherResponse) {
        locationLabel.text = weatherResponse.location.name
        weatherConditionLabel.text = weatherResponse.current.condition.text
        currentTemp = weatherResponse.current
        updateTemperatureUnit()

        weatherIcon.image = UIImage(named: "defaultWeatherIcon")

        if let iconURL = URL(string: "https:\(weatherResponse.current.condition.icon)") {
            URLSession.shared.dataTask(with: iconURL) { data, _, _ in
                if let data = data {
                    DispatchQueue.main.async { self.weatherIcon.image = UIImage(data: data) }
                }
            }.resume()
        }
    }
}

extension ViewController: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let location = locations.last {
            fetchWeatherForCurrentLocation(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude)
            locationManager.stopUpdatingLocation()
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        showAlert(message: "Unable to retrieve location.")
    }
}

extension ViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        searchTemp()
        textField.resignFirstResponder()
        return true
    }
}

struct WeatherResponse: Codable {
    let location: Location
    let current: currentTemp
    
    struct Location: Codable {
        let name: String
    }
    
    struct currentTemp: Codable {
        let tempCelsius: Double
        let tempFahrenheit: Double
        let condition: Condition
        
        enum CodingKeys: String, CodingKey {
            case tempCelsius = "temp_c"
            case tempFahrenheit = "temp_f"
            case condition
        }
    }
    
    struct Condition: Codable {
        let text: String
        let icon: String
    }
}

